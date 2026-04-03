#!/usr/bin/env bash
set -euo pipefail

# Generate amounts.json by merging classification.json with AWS Invoicing API data.
# Requires: classification.json in the invoice directory, mairu, aws CLI, jq

usage() {
  cat <<'EOF'
Usage: generate_amounts.sh [OPTIONS]

Required:
  --year YYYY          Billing year
  --month MM           Billing month (1-12)
  --account-id ID      AWS payer account ID
  --mairu-server SRV   mairu server name
  --mairu-role ROLE    mairu role
  --invoice-dir DIR    Invoice directory containing classification.json

Optional:
  --help               Show this help
EOF
  exit 1
}

YEAR=""
MONTH=""
ACCOUNT_ID=""
MAIRU_SERVER=""
MAIRU_ROLE=""
INVOICE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --year)         YEAR="$2"; shift 2 ;;
    --month)        MONTH="$2"; shift 2 ;;
    --account-id)   ACCOUNT_ID="$2"; shift 2 ;;
    --mairu-server) MAIRU_SERVER="$2"; shift 2 ;;
    --mairu-role)   MAIRU_ROLE="$2"; shift 2 ;;
    --invoice-dir)  INVOICE_DIR="$2"; shift 2 ;;
    --help)         usage ;;
    *)              echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$YEAR" || -z "$MONTH" || -z "$ACCOUNT_ID" || -z "$MAIRU_SERVER" || -z "$MAIRU_ROLE" || -z "$INVOICE_DIR" ]]; then
  echo "Error: Missing required arguments" >&2
  usage
fi

CLASSIFICATION="$INVOICE_DIR/classification.json"
if [[ ! -f "$CLASSIFICATION" ]]; then
  echo "Error: $CLASSIFICATION not found" >&2
  exit 1
fi

AWS_CMD=(mairu exec --server "$MAIRU_SERVER" "$MAIRU_ROLE" --)

# Fetch invoice summaries from API
echo "Fetching invoice summaries for ${YEAR}-$(printf '%02d' "$MONTH")..." >&2
API_JSON=$("${AWS_CMD[@]}" aws invoicing list-invoice-summaries \
  --selector "ResourceType=ACCOUNT_ID,Value=${ACCOUNT_ID}" \
  --filter "BillingPeriod={Month=${MONTH},Year=${YEAR}}" \
  --no-cli-pager 2>/dev/null)

# Build classification lookup and merge with API data
echo "Generating amounts.json..." >&2
jq -n --argjson api "$API_JSON" --slurpfile cls "$CLASSIFICATION" '

# Build classification lookup by invoice ID (strip .pdf)
($cls[0] | map({key: (.file | sub("\\.pdf$"; "")), value: .}) | from_entries) as $cls_lookup |

# Build API lookup for pair resolution
($api.InvoiceSummaries | map({key: .InvoiceId, value: .}) | from_entries) as $api_lookup |

def savings_plans_amount:
  [.BaseCurrencyAmount.AmountBreakdown.Discounts.Breakdown // [] | .[] |
    select(.Description | test("Savings Plan")) | .Amount | tonumber] | add // 0;

def credits_discounts_amount:
  [.BaseCurrencyAmount.AmountBreakdown.Discounts.Breakdown // [] | .[] |
    select(.Description | test("Credits|Discount")) | .Amount | tonumber] | add // 0;

[($api.InvoiceSummaries // [])[] |
  .InvoiceId as $id |
  ($cls_lookup[$id] // null) as $cls |
  if $cls == null then empty
  else
    if $cls.category == "non-marketplace" then
      {
        file: ($id + ".pdf"),
        category: $cls.category,
        subcategory: $cls.subcategory,
        label: $cls.label,
        currency: "USD",
        aws_service_charges: (.BaseCurrencyAmount.TotalAmount | tonumber),
        charges: (.BaseCurrencyAmount.AmountBreakdown.SubTotalAmount | tonumber),
        savings_plans: -(savings_plans_amount),
        credits_discounts: -(credits_discounts_amount),
        net_charges: (.BaseCurrencyAmount.TotalAmountBeforeTax | tonumber),
        jct: (.BaseCurrencyAmount.AmountBreakdown.Taxes.TotalAmount | tonumber),
        total_jpy: ((.TaxCurrencyAmount.TotalAmount // .PaymentCurrencyAmount.TotalAmount // "0") | tonumber)
      }
    else
      # For marketplace: use JPY from TaxCurrencyAmount
      # IINJP invoices may have null TaxCurrencyAmount — resolve via pair
      (if (.TaxCurrencyAmount.TotalAmount == null) and ($cls.pair_invoice != null) then
        $api_lookup[($cls.pair_invoice | sub("\\.pdf$"; ""))] // .
      else . end) as $src |
      {
        file: ($id + ".pdf"),
        category: $cls.category,
        subcategory: $cls.subcategory,
        label: $cls.label,
        currency: "JPY",
        charges: (($src.TaxCurrencyAmount.TotalAmountBeforeTax // "0") | tonumber),
        net_charges: (($src.TaxCurrencyAmount.TotalAmountBeforeTax // "0") | tonumber),
        jct: (($src.TaxCurrencyAmount.AmountBreakdown.Taxes.TotalAmount // "0") | tonumber),
        total: (($src.TaxCurrencyAmount.TotalAmount // "0") | tonumber)
      }
    end
  end
] | sort_by(.category, .subcategory, .label)
' > "$INVOICE_DIR/amounts.json"

echo "Written: $INVOICE_DIR/amounts.json" >&2
cat "$INVOICE_DIR/amounts.json"
