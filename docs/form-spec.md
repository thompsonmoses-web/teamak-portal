# Teamak Rider Ownership Programme — Form Specification

Source: `Teamak_Rider_Ownership_Programme_Application_Form.docx` (Ibadan & Environs).

ORGANISATION: TEAMAK GLOBAL SOLUTION LIMITED
ADDRESS: Solution Gospel Complex, Aba Opa, Ojoo, Ibadan
PHONE: +234 802 344 9126
TAGLINE: Ride with Dignity. Own Your Future.

Application number format: `TRP-<year>-<4-digit sequence>` (e.g. `TRP-2026-0001`).

## Programme tiers

| id | label | deposit (NGN) | months | asset |
|----|-------|---------------|--------|-------|
| `okada_650` | OKADA OWNERSHIP | 650000 | 3 | 1 brand-new Bajaj motorcycle |
| `okada_400` | OKADA OWNERSHIP | 400000 | 6 | 1 brand-new Bajaj motorcycle |
| `maruwa_2300` | MARUWA OWNERSHIP | 2300000 | 3 | 1 Bajaj/approved Maruwa tricycle |

NOTE: the contribution is a **one-time programme deposit**; no further vehicle payment
under the stated ownership offer, subject to programme approval, verification and the
applicable terms of the final agreement.

## Section A — Applicant information (`sectionA`)

| field | type | required | notes |
|-------|------|----------|-------|
| `fullName` | string | yes | |
| `phoneNumber` | string | yes | Nigerian format `0XXXXXXXXXX` or `+234XXXXXXXXXX` |
| `whatsappNumber` | string | no | |
| `residentialAddress` | string | yes | |
| `areaCommunity` | string | yes | |
| `dateOfBirth` | date | yes | ISO `YYYY-MM-DD` |
| `age` | int | no | >= 18 |
| `nin` | string | yes | exactly 11 digits |
| `maritalStatus` | enum | yes | `single` \| `married` \| `other` |
| `maritalStatusOther` | string | conditional | required when `other` |

## Section B — Rider / operator information (`sectionB`)

| field | type | required | notes |
|-------|------|----------|-------|
| `operationType` | enum | yes | `okada` (motorcycle) \| `maruwa` (tricycle) |
| `ridingExperience` | enum | yes | `lt1` \| `y1_3` \| `y4_6` \| `y7_plus` |
| `currentVehicleOwnership` | enum | yes | `owned` \| `rented` \| `hired_leased` \| `other` |
| `currentVehicleOther` | string | conditional | required when `other` |
| `vehicleMakeModel` | string | no | |
| `parkRouteOperatingArea` | string | yes | |
| `parkAssociationName` | string | yes | |
| `currentRemittance` | string | yes | daily/weekly remittance as displayed |
| `averageWorkingDaysPerWeek` | int | yes | 0–7 |

## Section C — Programme applied for (`sectionC`)

| field | type | required | notes |
|-------|------|----------|-------|
| `programmeId` | enum | yes | one of the tier ids above |

## Section D — Payment / funding (`sectionD`)

| field | type | required | notes |
|-------|------|----------|-------|
| `amountToCommit` | int | yes | NGN, > 0 |
| `sourceOfFunds` | enum[] | yes | `personal_savings` \| `business_income` \| `family_support` \| `other` |
| `sourceOfFundsOther` | string | conditional | required when `other` included |
| `expectedDepositDate` | date | yes | ISO date |
| `participatedBefore` | bool | yes | |
| `previousProgrammeDetails` | string | conditional | required when `participatedBefore` = true |

## Section E — Identification & verification (`sectionE`)

Checklist of provided documents (bool flags; uploaded files stored separately):

| field | notes |
|-------|-------|
| `hasPassportPhotograph` | |
| `hasGovernmentIdOrNinSlip` | |
| `hasRiderOrAssociationRegistration` | park verification |
| `hasProofOfResidentialAddress` | |
| `hasTwoPassportPhotographs` | |

## Section F — Next of kin (`sectionF`)

| field | type | required |
|-------|------|----------|
| `fullName` | string | yes |
| `relationship` | string | yes |
| `phoneNumber` | string | yes |
| `address` | string | yes |

## Section G — Two references (`sectionG`)

Array of exactly 2 entries:

| field | type | required |
|-------|------|----------|
| `fullName` | string | yes |
| `relationship` | string | yes |
| `phoneNumber` | string | yes |
| `address` | string | yes |

## Section H — Declaration (`sectionH`)

| field | type | required |
|-------|------|----------|
| `declarationAccepted` | bool (must be true) | yes |
| `signatureName` | string | yes |
| `declarationDate` | date | yes |

Declaration text: applicant applies to participate in the Teamak Global Solution Limited
Rider Ownership Programme; confirms information is true and accurate; understands that
submitting the form does not itself constitute approval or guarantee of asset allocation;
agrees to verification and to sign the programme/asset ownership agreement before final
participation; understands terms, delivery conditions, documentation, registration and
other requirements will be communicated before final acceptance.

## Section I — For official use only (`sectionI`, staff only)

| field | type | required |
|-------|------|----------|
| `receivedBy` | string | no |
| `verificationStatus` | enum | yes on update: `pending` \| `approved` \| `not_approved` \| `further_review` |
| `verificationDate` | date | no |
| `approvedProgrammeId` | tier id | no |
| `approvedAmount` | int | no |
| `expectedDeliveryDate` | date | no |
| `remarks` | string | no |

## Application status flow

`submitted` → `pending` → `approved` | `not_approved` | `further_review`
(any non-terminal state may move to any of the three; changes are recorded in
`application_events` with staff id, timestamp and remark)
