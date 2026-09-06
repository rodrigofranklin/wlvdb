# Cite the database, results and sources

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[Português](citation-pt.md) | English | [Use the data](use-results-en.md) | [Theoretical references](references-en.md) | [Home](../README.md)

A project reference acknowledges authorship and makes the project findable.
A data note identifies the material supporting an analysis. Use both: citing
the methodological article alone does not identify the source editions, code,
selections and results used.

## Distinguish the cited objects

| Object | Identification to preserve |
| --- | --- |
| Theoretical and methodological foundations | Franklin et al. (2022) and Franklin (2025), according to the concept and method discussed; full references are on the bibliography page. |
| WLVDB software | Project name, repository, commit actually used and access date. |
| Native result | Method, source/contract versions, `run_id`, `result_id`, `release_id` and complete manifests. |
| Website selection | Access address, date, file, indicators, filters, units and identifiers actually supplied. |
| Subsequent analysis | Script, version, transformations, exclusions and reasons, distinguishing them from database calculations. |

Results are available through [World Labour Values](https://panel.worldlabourvalues.org/)
and [LabCidades/UFES](http://labcidades.ufes.br/worldlabourvalues/).
Use the address through which you obtained the selection. An export may supply
less metadata than a native publication; record fields not supplied rather
than filling them with the repository's current commit or assumed identifiers.

## Data-note template for an export

Replace each bracketed field with information from your analysis. This is an
editorial template, not a description of a completed run.

> Results source: World Labour Values Database (WLVDB), obtained through
> [address] on [date]. Original file: [name and format]. Method: [method].
> Indicator: [code and description]. Countries/industries: [codes and
> classification]. Period: [years]. Population and productive scope:
> [definition]. Received unit: [ratio, percentage, index, hours or monetary
> unit]. Publication identifiers supplied: [fields and values; or “not supplied
> with the export”]. Transformations: [procedures, including scaling]. Coverage
> and exclusions: [decisions and reasons]. Analysis script: [file and version].

For the introductory question in this manual, the scope description is
“Brazil (`BRA`), `wiodr13`, `surplus_value.empe_p.r.pc`, employees in productive
industries, 1995–2007”. This identifies a **proposed selection**, not empirical
values, and does not remove the need to assess coverage.

## Data-note template for a native publication

> WLVDB results: method [method], years [years], run [run_id], content
> [result_id], release [release_id]. Calculation code: [commit recorded in the
> manifest]. Source: [edition, deposit and file identities]. Contracts:
> [source, unit and output versions]. Indicators and scope: [selection].
> States and anomalies: [preserved artifacts and use decisions]. Analysis:
> [script and version]. Access date: [date]. Complete manifests archived with
> the study at [location or persistent identifier].

The calculation and analysis commits may differ. Channel name `stable` does
not replace an immutable release. A checksum identifies bytes; it does not
demonstrate an assumption's validity or equivalence between methodologies.

## Software and data reference templates

Preserve authorship declared in the cited version. The templates below use
the project title as the entry and follow a bibliographic identification
structure; they do not invent personal authorship or an unverified release date.

**WORLD LABOUR VALUES DATABASE (WLVDB).** Source code. Revision [commit].
[Project repository](https://github.com/rodrigofranklin/wlvdb).
Accessed: [day month year].

**WORLD LABOUR VALUES DATABASE (WLVDB).** Results: [method and period].
Release [release_id], run [run_id], content [result_id].
[World Labour Values](https://panel.worldlabourvalues.org/).
Accessed: [day month year].

An export without these IDs should be cited using its actual file, scope,
address and acquisition date. Do not copy brackets as though they were
identifiers. When citing an article's results, identify its selection and
version; running current code does not establish reproduction of its
historical tables.

## Statistical sources and the WIOD usage reference

Edition titles and DOIs identify sources; manifests and contracts identify
exact files accepted by the calculation. Deposit year 2021 is neither the
2013/2016 edition year nor the observation period. The WIOD13 source coverage
below exceeds that of the WLVDB method.

TIMMER, Marcel; DIETZENBACHER, Erik; LOS, Bart; STEHRER, Robert; DE VRIES,
Gaaitzen. **World Input-Output Database 2013 Release, 1995–2011**.
DataverseNL, 2021. Dataset. DOI:
[10.34894/XDTAUZ](https://doi.org/10.34894/XDTAUZ).
Accessed: 6 Sept. 2026.

TIMMER, Marcel; DIETZENBACHER, Erik; LOS, Bart; STEHRER, Robert; DE VRIES,
Gaaitzen. **World Input-Output Database 2016 Release, 2000–2014**.
DataverseNL, 2021. Dataset. DOI:
[10.34894/PJ2M1C](https://doi.org/10.34894/PJ2M1C).
Accessed: 6 Sept. 2026.

TIMMER, Marcel P.; DIETZENBACHER, Erik; LOS, Bart; STEHRER, Robert;
DE VRIES, Gaaitzen J. An illustrated user guide to the World Input-Output
Database: the case of global automotive production.
**Review of International Economics**, v. 23, n. 3, p. 575–605, 2015.
DOI: [10.1111/roie.12178](https://doi.org/10.1111/roie.12178).

THE VIENNA INSTITUTE FOR INTERNATIONAL ECONOMIC STUDIES (wiiw).
**The EU KLEMS 2019 data repository**. Vienna: wiiw, 2019.
Available at: [official 2019 archive](https://euklems.eu/archive-history/).
Accessed: 6 Sept. 2026.

Bibliographic identification was checked against the
[University of Groningen portal](https://research.rug.nl/en/publications/an-illustrated-user-guide-to-the-world-input-output-database-the-/)
and the official EU KLEMS archive. The official
[WIOD13](https://www.rug.nl/ggdc/valuechain/wiod/wiod-2013-release?lang=en) and
[WIOD16](https://www.rug.nl/ggdc/valuechain/wiod/wiod-2016-release?lang=en)
pages request a reference to Timmer et al. (2015). EU KLEMS also points to its
construction and analysis reports for attribution according to use. Consult
those instructions when preparing a study's bibliography.

Employment, hours and concordance supplements do not become new WIOD
observations by being used in the program. Cite their providers and WLVDB
transformations according to [sources and attribution](guide-en.md#sources-and-attribution)
and run manifests. Do not replace a pinned edition with another sharing its name.
