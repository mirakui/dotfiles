#!/usr/bin/env bash
set -euo pipefail

# AWS Invoice PDF Downloader
# Downloads all invoice PDFs for a specified billing period using mairu + AWS Invoicing API.

usage() {
  cat <<'EOF'
Usage: download_invoices.sh [OPTIONS]

Required:
  --year YYYY          Billing year
  --month MM           Billing month (1-12)
  --account-id ID      AWS account ID (payer account)
  --mairu-server SRV   mairu server name
  --mairu-role ROLE    mairu role (e.g. "096692119455/ReadOnlyAccess")

Optional:
  --output-dir DIR     Output directory (default: ./aws-invoices-YYYY-MM/)
  --help               Show this help
EOF
  exit 1
}

YEAR=""
MONTH=""
ACCOUNT_ID=""
MAIRU_SERVER=""
MAIRU_ROLE=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --year)       YEAR="$2"; shift 2 ;;
    --month)      MONTH="$2"; shift 2 ;;
    --account-id) ACCOUNT_ID="$2"; shift 2 ;;
    --mairu-server) MAIRU_SERVER="$2"; shift 2 ;;
    --mairu-role) MAIRU_ROLE="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --help)       usage ;;
    *)            echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$YEAR" || -z "$MONTH" || -z "$ACCOUNT_ID" || -z "$MAIRU_SERVER" || -z "$MAIRU_ROLE" ]]; then
  echo "Error: Missing required arguments" >&2
  usage
fi

# Zero-pad month
MONTH_PAD=$(printf "%02d" "$MONTH")

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$HOME/Downloads/invoices/aws-${YEAR}-${MONTH_PAD}"
fi

AWS_CMD=(mairu exec --server "$MAIRU_SERVER" "$MAIRU_ROLE" --)

# Verify authentication
echo "Verifying AWS authentication..."
if ! "${AWS_CMD[@]}" aws sts get-caller-identity > /dev/null 2>&1; then
  echo "Error: AWS authentication failed. Run 'mairu login $MAIRU_SERVER' first." >&2
  exit 1
fi
echo "Authentication OK."

# List invoices for the billing period
echo "Fetching invoice list for ${YEAR}-${MONTH_PAD}..."
INVOICES_JSON=$("${AWS_CMD[@]}" aws invoicing list-invoice-summaries \
  --selector "ResourceType=ACCOUNT_ID,Value=${ACCOUNT_ID}" \
  --filter "BillingPeriod={Month=${MONTH},Year=${YEAR}}" \
  --no-cli-pager 2>&1)

INVOICE_COUNT=$(echo "$INVOICES_JSON" | jq '.InvoiceSummaries | length')

if [[ "$INVOICE_COUNT" -eq 0 ]]; then
  echo "No invoices found for ${YEAR}-${MONTH_PAD}."
  exit 0
fi

echo "Found ${INVOICE_COUNT} invoice(s)."
mkdir -p "$OUTPUT_DIR"

# Print summary header
printf "\n%-20s %-30s %15s %s\n" "Invoice ID" "Entity" "Amount" "Status"
printf "%-20s %-30s %15s %s\n" "--------------------" "------------------------------" "---------------" "------"

# Download each invoice
DOWNLOAD_OK=0
DOWNLOAD_FAIL=0

for i in $(seq 0 $((INVOICE_COUNT - 1))); do
  INVOICE_ID=$(echo "$INVOICES_JSON" | jq -r ".InvoiceSummaries[$i].InvoiceId")
  ENTITY=$(echo "$INVOICES_JSON" | jq -r ".InvoiceSummaries[$i].Entity.InvoicingEntity")
  TOTAL=$(echo "$INVOICES_JSON" | jq -r ".InvoiceSummaries[$i].BaseCurrencyAmount.TotalAmount")
  CURRENCY=$(echo "$INVOICES_JSON" | jq -r ".InvoiceSummaries[$i].BaseCurrencyAmount.CurrencyCode")

  # Get presigned PDF URL
  PDF_URL=$("${AWS_CMD[@]}" aws invoicing get-invoice-pdf \
    --invoice-id "$INVOICE_ID" \
    --no-cli-pager \
    --query 'InvoicePDF.DocumentUrl' \
    --output text 2>&1)

  if [[ "$PDF_URL" == http* ]]; then
    FILENAME="${INVOICE_ID}.pdf"
    if curl -sS -o "${OUTPUT_DIR}/${FILENAME}" "$PDF_URL"; then
      printf "%-20s %-30s %12s %s %s\n" "$INVOICE_ID" "$ENTITY" "$TOTAL" "$CURRENCY" "OK"
      DOWNLOAD_OK=$((DOWNLOAD_OK + 1))
    else
      printf "%-20s %-30s %12s %s %s\n" "$INVOICE_ID" "$ENTITY" "$TOTAL" "$CURRENCY" "CURL_FAIL"
      DOWNLOAD_FAIL=$((DOWNLOAD_FAIL + 1))
    fi
  else
    printf "%-20s %-30s %12s %s %s\n" "$INVOICE_ID" "$ENTITY" "$TOTAL" "$CURRENCY" "URL_FAIL"
    DOWNLOAD_FAIL=$((DOWNLOAD_FAIL + 1))
  fi
done

echo ""
echo "Download complete: ${DOWNLOAD_OK} OK, ${DOWNLOAD_FAIL} failed"
echo "Output directory: ${OUTPUT_DIR}"
ls -la "$OUTPUT_DIR"
