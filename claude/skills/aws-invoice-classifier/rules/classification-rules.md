# AWS Invoice Classification Rules

## Invoice ID Prefixes

| Prefix | Issuer | Type | is_jp_invoice |
|---|---|---|---|
| `JPIN` | Amazon Web Services Japan G.K. | AWS service charges (Tax Invoice) | true |
| `JPMPIN` | Amazon Web Services Japan G.K. | Marketplace charges (Tax Invoice) | true |
| `IINJP` | Amazon Web Services, Inc. | Tax Invoice (JP qualified) for AWS Inc charges | true |
| Numeric (e.g. `2524807621`) | Amazon Web Services, Inc. | AWS Inc Invoice (not JP qualified) | false |

## Pair Invoice Detection

- IINJP invoices contain text like "applied to Invoice #XXXXXXX" — the referenced number is the pair
- Numeric ID invoices and IINJP invoices with the same linked accounts and amounts are pairs
- JPIN and JPMPIN invoices do NOT have pairs

## Category Rules

### marketplace
- JPMPIN invoices (always marketplace)
- Invoices with "Purchases on Marketplace" or "AWS Marketplace Charges" in summary
- "Contact Center Telecommunications (service sold by AMCS, LLC)" — label as `amazon-connect`
- Third-party products sold via AWS Marketplace (Datadog, Anthropic, etc.)

### non-marketplace
- JPIN invoices with "AWS Service Charges" in summary
- Standard AWS service usage (EC2, S3, RDS, etc.)

## Subcategory Rules

| category | subcategory |
|---|---|
| non-marketplace | `monthly-usage` |
| marketplace | `null` |

## Label Rules (kebab-case)

### non-marketplace
Determine from "Linked Account Allocation" section:
- Single account → use account name as label (e.g. `ivry-prd`, `ivry-stg`, `ivry-databricks`)
- Multiple accounts → describe the mix (e.g. `dev-inc-corp-mixed`)
- Use kebab-case, lowercase

### marketplace
Use the vendor/product name as label:
- Datadog → `datadog`
- Anthropic/Claude (Bedrock Edition) → `anthropic`
- Contact Center Telecommunications → `amazon-connect`
- Other vendors → derive kebab-case label from vendor name

## Account ID Mapping (ivry organization)

| Account ID | Name |
|---|---|
| 096692119455 | ivry-inc (payer) |
| 146154011163 | ivry-prd |
| 444770236657 | ivry-corp |
| 895663540920 | ivry-stg |
| 905418355005 | ivry-dev |
| 977099017500 | ivry-databricks |

## Output Format

Write `classification.json` in the target directory. Each entry:

```json
{
  "file": "JPIN26-744773.pdf",
  "category": "non-marketplace",
  "subcategory": "monthly-usage",
  "label": "ivry-databricks",
  "invoicing_entity": "Amazon Web Services Japan G.K.",
  "linked_accounts": [{"name": "ivry-databricks", "account_id": "977099017500"}],
  "pair_invoice": null,
  "is_jp_invoice": true,
  "notes": "EC2/S3/Data Transfer等"
}
```

### Field Reference

| Field | Type | Description |
|---|---|---|
| `file` | string | PDF filename |
| `category` | string | `non-marketplace` or `marketplace` |
| `subcategory` | string/null | `monthly-usage` for non-marketplace, `null` for marketplace |
| `label` | string | kebab-case classification label |
| `invoicing_entity` | string | Full name of the invoicing entity from the PDF |
| `linked_accounts` | array | `[{"name": "...", "account_id": "..."}]` from Linked Account Allocation |
| `pair_invoice` | string/null | Filename of the paired invoice (IINJP ↔ numeric ID) |
| `is_jp_invoice` | boolean | true if JP qualified tax invoice (JPIN, JPMPIN, IINJP) |
| `notes` | string | Brief description of main services/products in the invoice |
