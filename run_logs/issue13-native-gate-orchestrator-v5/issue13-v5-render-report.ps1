param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$StatePath,
  [Parameter(Mandatory = $true)][string]$Output,
  [switch]$ConfirmWriteReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $ConfirmWriteReport) {
  throw 'Report generation requires -ConfirmWriteReport.'
}
$scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $scriptRoot 'issue13-v5-coordinator-lib.ps1')

$binding = Assert-Issue13V5Config $ConfigPath
$config = $binding.config
$expectedStatePath = ConvertTo-Issue13V5Path (Get-Issue13V5StatePath $config)
$providedStatePath = ConvertTo-Issue13V5Path (
  (Resolve-Path -LiteralPath $StatePath).Path)
if (-not [string]::Equals($providedStatePath, $expectedStatePath,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Report state path is not the canonical control-root gate-state.json.'
}
$state = Read-Issue13V5State $config $binding.sha256
if ([string]$state.schema -cne 'wlv-issue13-v5-coordinator-state/1' -or
    [string]$state.config_sha256 -cne [string]$binding.sha256 -or
    [string]$state.final_aggregate.status -cne 'passed' -or
    [string]$state.prep_fault.aggregate_status -cne 'passed' -or
    @($state.phases | Where-Object comparison_status -cne 'completed').Count `
      -ne 0 -or
    @($state.prep_fault.faults | Where-Object status -cne 'executed').Count `
      -ne 0) {
  throw 'Only a complete passed V5 state can produce the report.'
}
if ((Get-Issue13V5Sha256 $state.final_aggregate.path) -cne
    [string]$state.final_aggregate.sha256) {
  throw 'Final aggregate changed before report generation.'
}
$null = Assert-Issue13V5FinalBindings $config $state

$repository = (Resolve-Path -LiteralPath $config.repository_root).Path
$head = (& git -C $repository rev-parse HEAD 2>$null).Trim()
$trackedStatus = @(& git -C $repository status '--porcelain=v1' `
  '--untracked-files=no' 2>$null)
if ($LASTEXITCODE -ne 0 -or $head -cne [string]$config.candidate_commit -or
    $trackedStatus.Count -ne 0) {
  throw 'Report generation requires the pinned candidate HEAD and tracked-clean tree.'
}

$outputPath = ConvertTo-Issue13V5Path $Output
if (Test-Path -LiteralPath $outputPath) {
  throw "Report output already exists: $outputPath"
}
$expectedOutput = ConvertTo-Issue13V5Path (
  Join-Path $repository ([string]$config.report.required_path))
if (-not [string]::Equals($outputPath, $expectedOutput,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Report output differs from the configured required path.'
}

$aggregatePath = [string]$state.final_aggregate.path
$aggregateRoot = Split-Path -Parent $aggregatePath
$aggregate = Read-Issue13V5Json $aggregatePath
$prepFault = Read-Issue13V5Json $state.prep_fault.aggregate_path
$strictSmoke = Read-Issue13V5Json $config.strict_baseline_smoke.path
$compatibilitySmoke = Read-Issue13V5Json `
  $config.compatibility_baseline_smoke.path
$preparation = Read-Issue13V5Json `
  $state.prep_fault.preparation_comparison_path
$preparationPassed = [string]$preparation.status -ceq 'passed'
$paperComparisonPath = Join-Path (
  Get-Issue13V5ComparisonDirectory $config 'parity/paper/0') 'comparison.json'
$paperComparison = Read-Issue13V5Json $paperComparisonPath
$performance = @(Import-Csv -LiteralPath (
  Join-Path $aggregateRoot 'performance.csv'))
$oracle = @(Import-Csv -LiteralPath (
  Join-Path $aggregateRoot 'oracle-classification.csv'))
$checks = @(Import-Csv -LiteralPath (Join-Path $aggregateRoot 'checks.csv'))
if ($performance.Count -ne 76 -or
    @($performance | Where-Object {
      [string]$_.time_passed -cne 'TRUE' -or
      [string]$_.rss_passed -cne 'TRUE'
    }).Count -ne 0 -or
    $checks.Count -le 0 -or
    $checks.Count -ne [long]$aggregate.check_count -or
    @($checks | Where-Object { [string]$_.passed -cne 'TRUE' }).Count -ne 0 -or
    -not $preparationPassed -or -not [bool]$paperComparison.passed -or
    [bool]$strictSmoke.passed -or [long]$strictSmoke.passed_count -ne 5 -or
    [long]$strictSmoke.failed_count -ne 7 -or
    -not [bool]$compatibilitySmoke.passed -or
    [long]$compatibilitySmoke.passed_count -ne 12 -or
    [long]$compatibilitySmoke.failed_count -ne 0) {
  throw 'Passed aggregate tables or paper comparison are inconsistent.'
}

$commandRoot = Join-Path ([string]$config.control_root) 'commands'
$commandRecords = @(Get-ChildItem -LiteralPath $commandRoot -Filter '*.json' `
  -File | Sort-Object Name | ForEach-Object { Read-Issue13V5Json $_.FullName })
$commandInventory = Get-Issue13V5TreeInventory $commandRoot
$evidenceInventory = Get-Issue13V5TreeInventory $config.evidence_root
$aggregateInventory = Get-Issue13V5TreeInventory $aggregateRoot

$baselineSeconds = [double](($performance | Measure-Object `
  baseline_seconds -Sum).Sum)
$candidateSeconds = [double](($performance | Measure-Object `
  candidate_seconds -Sum).Sum)
$maximumTimeRatio = ($performance | ForEach-Object {
  [double]$_.candidate_seconds / [double]$_.baseline_seconds
} | Measure-Object -Maximum).Maximum
$maximumCandidateRss = ($performance | ForEach-Object {
  [int64]$_.candidate_peak_rss_bytes
} | Measure-Object -Maximum).Maximum
$maximumRssUtilization = ($performance | ForEach-Object {
  [double]$_.candidate_peak_rss_bytes / [double]$_.rss_limit_bytes
} | Measure-Object -Maximum).Maximum
$oracleGroups = @($oracle | Group-Object classification | Sort-Object Name)
$faultRows = @($state.prep_fault.faults | Sort-Object fault_id)

$sourceIdentityLines = [Collections.Generic.List[string]]::new()
foreach ($sourceName in @('wiodr13', 'wiodr16')) {
  $sourceComparison =
    $preparation.sources.PSObject.Properties[$sourceName].Value
  $baselineManifest = $sourceComparison.baseline_manifest
  $candidateManifest = $sourceComparison.candidate_manifest
  $manifestComparison =
    $sourceComparison.csv.PSObject.Properties['_source_manifest.csv'].Value
  $identityFields = @(
    'source_generation_id', 'contract_id', 'contract_version', 'contract_sha256')
  if (-not [bool]$sourceComparison.passed -or
      -not [bool]$sourceComparison.manifest_tables_identical -or
      -not [bool]$baselineManifest.passed -or
      -not [bool]$candidateManifest.passed -or
      -not [bool]$manifestComparison.passed -or
      [string]$manifestComparison.baseline_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$manifestComparison.candidate_sha256 -cnotmatch
        '^[0-9a-f]{64}$') {
    throw "Preparation source manifest is not identical: $sourceName"
  }
  foreach ($field in $identityFields) {
    if ([string]::IsNullOrWhiteSpace([string]$baselineManifest.$field) -or
        [string]$baselineManifest.$field -cne
          [string]$candidateManifest.$field) {
      throw "Preparation source identity differs: $sourceName/$field"
    }
  }
  if ([string]$baselineManifest.source_generation_id -cnotmatch
        '^[0-9a-f]{64}$' -or
      [string]$baselineManifest.contract_sha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw "Preparation source identity hash is invalid: $sourceName"
  }
  $sourceIdentityLines.Add(
    '- `' + $sourceName + '`: source_generation_id `' +
      [string]$baselineManifest.source_generation_id + '`, contract_id `' +
      [string]$baselineManifest.contract_id + '`, contract_version `' +
      [string]$baselineManifest.contract_version + '`, contract_sha256 `' +
      [string]$baselineManifest.contract_sha256 + '`, manifest SHA-256 ' +
      'baseline `' + [string]$manifestComparison.baseline_sha256 + '`, ' +
      'candidato `' + [string]$manifestComparison.candidate_sha256 +
      '` (tabelas semanticamente idênticas).'
  )
}
$euklemsArtifacts = @(
  $preparation.euklems.artifacts.PSObject.Properties | ForEach-Object {
    $_.Value
  })
if (-not [bool]$preparation.euklems.passed -or
    [long]$preparation.euklems.artifact_count -ne 42L -or
    $euklemsArtifacts.Count -ne 42 -or
    [string]::Join(',', @($preparation.euklems.expected_years)) -cne
      [string]::Join(',', (1995..2015)) -or
    [string]::Join(',', @($preparation.euklems.expected_series)) -cne
      'ekk,ekdeprate' -or
    @($euklemsArtifacts | Where-Object {
      -not [bool]$_.passed -or
      [string]$_.baseline_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0) {
  throw 'EU KLEMS prepared artifact identity is incomplete or differs.'
}
$euklemsIdentityPayload = [string]::Join("`n", @(
  $euklemsArtifacts | Sort-Object artifact | ForEach-Object {
    [string]$_.artifact + '|' + [string]$_.baseline_sha256 + '|' +
      [string]$_.candidate_sha256
  }))
$euklemsIdentitySha256 = Get-Issue13V5TextSha256 $euklemsIdentityPayload
$sourceIdentityLines.Add(
  '- `euklems`: 42 FSTs (1995–2015, `ekk`/`ekdeprate`) com esquemas e ' +
    'células idênticos; identidade agregada dos hashes de ambos os braços `' +
    $euklemsIdentitySha256 +
    '`. O contrato atual não publica `_source_manifest.csv` para EU KLEMS; ' +
    'as duas caches oficiais e cada artefato preparado são autenticados.'
)

$sourceCacheLines = @($script:Issue13V5PreparationCaches | ForEach-Object {
  '- `' + $_.relative_path.Replace('\', '/') + '`: `' + $_.sha256 +
    '` (' + [string]$_.size_bytes + ' bytes)'
})
$commandGroups = @($commandRecords | Group-Object {
  ([string]$_.label).Split('/')[0]
} | Sort-Object Name)
$commandLines = @($commandGroups | ForEach-Object {
  $executables = @($_.Group.executable | ForEach-Object {
    [IO.Path]::GetFileName([string]$_)
  } | Sort-Object -Unique)
  '- `' + $_.Name + '/*`: ' + [string]$_.Count +
    ' comandos via `' + ($executables -join ', ') + '`'
})
$oracleLines = if ($oracleGroups.Count) {
  @($oracleGroups | ForEach-Object {
    '- `' + $_.Name + '`: ' + [string]$_.Count
  })
} else { @('- Nenhuma classificação de oracle foi emitida.') }
$faultLines = @($faultRows | ForEach-Object {
  '- `' + $_.fault_id + '`: `passed`, resultado `' + $_.result_sha256 + '`'
})

$text = @"
# Issue #13 — relatório integral de paridade V5

Este documento registra o gate real, write-once e sem reutilização de evidência
do rework atômico do motor. O merge do issue #12 permanece a origem histórica
imutável. Como ele falha antes de produzir sete oráculos, a execução final do
baseline usa um único filho direto de compatibilidade, autenticado pela íntegra
de seu diff. O smoke estrito 5/7 é preservado como evidência negativa e nunca é
importado como resultado científico final.

## Identidade

- `baseline_commit`: `$($config.baseline_commit)`
- `baseline_base_commit`: `$($config.baseline_base_commit)`
- `baseline_runtime_commit`: `$($config.baseline_runtime_commit)`
- `candidate_commit`: `$($config.candidate_commit)`
- Gate: 12 métodos, 76 pares, 162 cenários monitorados, 202 comparações e 10
  falhas injetadas.
- Agregado: `$aggregatePath`
- Estado final: `$StatePath`

## source_ids

- Inventário oficial: `$($config.source_inventory.inventory_sha256)`
  ($($config.source_inventory.file_count) arquivos,
  $($config.source_inventory.total_bytes) bytes).
- Inventário de diretórios: `$($config.source_inventory.directory_list_sha256)`.
$([string]::Join("`n", $sourceCacheLines))

Identidades das gerações preparadas (validadas como iguais entre baseline e
candidato):

$([string]::Join("`n", $sourceIdentityLines))

## commands

Os comandos foram registrados individualmente com argumentos, código de saída,
tempo e hashes de stdout/stderr. Inventário autenticado:
`$($commandInventory.inventory_sha256)` ($($commandInventory.file_count) arquivos).

$([string]::Join("`n", $commandLines))

## hashes

- Configuração V5: `$($binding.sha256)`
- Harness materializado: `$($binding.harness_inventory.inventory_sha256)`
- Índice baseline compatibility-oracle-cc2: `$($config.baseline_runtime_index_sha256)`
- `baseline_overlay_patch`: `$($config.baseline_overlay.sha256)`
  (stable patch-id `$($config.baseline_overlay.patch_id)`).
- `strict_baseline_smoke`: `$($config.strict_baseline_smoke.sha256)`.
- `compatibility_baseline_smoke`:
  `$($config.compatibility_baseline_smoke.sha256)`.
- Evidência final: `$($evidenceInventory.inventory_sha256)`
- Agregado final: `$($state.final_aggregate.sha256)`
- Envelope do agregado: `$($aggregateInventory.inventory_sha256)`
- Subagregado preparação/falhas: `$(Get-Issue13V5Sha256 $state.prep_fault.aggregate_path)`
- Comparação paper 0: `$(Get-Issue13V5Sha256 $paperComparisonPath)`

## times

- Tempo baseline somado: `$([Math]::Round($baselineSeconds, 3))` segundos.
- Tempo candidato somado: `$([Math]::Round($candidateSeconds, 3))` segundos.
- Maior razão candidato/baseline: `$([Math]::Round($maximumTimeRatio, 6))`
  (limite `1.2`).
- Todos os 76 limites de tempo passaram: `TRUE`.

## peak_rss

- Maior RSS candidato: `$maximumCandidateRss` bytes.
- Maior utilização do limite RSS: `$([Math]::Round($maximumRssUtilization, 6))`.
- Regra: baseline + `max(10%, 512 MiB)`; todos os 76 pares passaram.
- WIOD13/WIOD16 com `workers=2`: equivalentes a `workers=1`, contagem exata de
  workers e `cluster_closed=true`.

## differences

- Checks executados: `$($aggregate.check_count)`; falhas: `0`.
- O smoke estrito em `cc2c861` passou 5 métodos e falhou 7; sua evidência é
  negativa e `final_evidence_eligible=false`.
- O smoke do oráculo filho passou os 12 métodos; ele também é apenas preflight
  e `final_evidence_eligible=false`.
- A única alteração do baseline executável é o patch integral autenticado do
  filho direto; nenhuma alteração dele pertence ao candidato ou ao PR.
- A única diferença arquitetural aceita é o sidecar candidato
  `_runtime_resources.rds`, validado pelo runtime candidato contra os hashes dos
  artefatos, coordenadas semânticas e bindings do run imutável.
- `_nonfinite_resolution_diagnostics.csv` é candidato-only conforme contrato.
- Não foi introduzida tolerância numérica nova.
$([string]::Join("`n", $oracleLines))

## preparation_results

- Status: `$($preparation.status)`; passed: `$preparationPassed`.
- WIOD13, WIOD16 e EU KLEMS foram preparados a partir das mesmas seis caches
  oficiais autenticadas.
- Arrays normativos foram comparados bit a bit, preservando `NA`, `NaN`,
  infinitos e zero assinado.
- Promoção atômica e ausência de staging/locks foram verificadas.

## paper0_results

- Status da comparação semântica do workbook: `$($paperComparison.status)`.
- Métodos: `ochoa_1` e `ochoa_2`.
- O release e as células/sheets do workbook foram comparados semanticamente.
- Papers 3 e 4 permanecem não suportados no preflight.

## fault_results

- Falhas injetadas aprovadas: `$($prepFault.summary.fault_gates_passed)`.
- Rollbacks aprovados: `$($prepFault.summary.rollback_gates_passed)`.
- Releases parciais visíveis: `$($prepFault.summary.visible_partial_releases)`.
- Entradas de staging/lock remanescentes: `$($prepFault.summary.staging_entries)`.
$([string]::Join("`n", $faultLines))

## Conclusão

O agregado V5 passou integralmente. A evidência está vinculada à origem
`cc2c861`, ao runtime-oráculo filho autenticado, ao commit candidato acima, às
fontes oficiais e ao tooling V5 materializado. Qualquer alteração posterior em
configuração, harness, cenários, comparações, logs ou artefatos invalida os
hashes registrados neste relatório.
"@

$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $parent
}
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$temporary = Join-Path $parent ('.issue-13.md-' +
  [Guid]::NewGuid().ToString('N') + '.tmp')
[IO.File]::WriteAllText($temporary, $text, $utf8)
$roundtrip = [IO.File]::ReadAllText($temporary, $utf8)
if (-not [string]::Equals($roundtrip, $text,
    [StringComparison]::Ordinal) -or $roundtrip.Contains([char]0xFFFD)) {
  throw 'Issue #13 report UTF-8 round trip failed.'
}
foreach ($field in @($config.report.required_fields)) {
  if ($roundtrip -cnotmatch [regex]::Escape([string]$field)) {
    throw "Report lacks configured field: $field"
  }
}
[IO.File]::Move($temporary, $outputPath)
if (-not [string]::Equals(
    [IO.File]::ReadAllText($outputPath, $utf8), $text,
    [StringComparison]::Ordinal)) {
  throw 'Installed Issue #13 report differs from verified UTF-8 payload.'
}
[pscustomobject]@{
  status = 'written'
  path = (Resolve-Path -LiteralPath $outputPath).Path
  sha256 = Get-Issue13V5Sha256 $outputPath
  baseline_commit = [string]$config.baseline_commit
  baseline_runtime_commit = [string]$config.baseline_runtime_commit
  candidate_commit = [string]$config.candidate_commit
}
