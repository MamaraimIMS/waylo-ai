#!/usr/bin/env bash
# =============================================================================
# WayloAI · End-to-End Webhook Test
# =============================================================================
# Использование:
#   bash test-webhook.sh path/to/document.docx
#   bash test-webhook.sh path/to/document.pdf
#
# Требует установленного WAYLO_WEBHOOK_URL в окружении:
#   export WAYLO_WEBHOOK_URL="https://xxxxx.app.n8n.cloud/webhook/waylo-intake"
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -eq 0 ]; then
  echo -e "${RED}Error: Provide path to .docx or .pdf file${NC}"
  echo "Usage: $0 path/to/document.docx"
  exit 1
fi

FILE_PATH="$1"

if [ ! -f "$FILE_PATH" ]; then
  echo -e "${RED}Error: File not found: $FILE_PATH${NC}"
  exit 1
fi

# Check webhook URL
if [ -z "$WAYLO_WEBHOOK_URL" ]; then
  echo -e "${YELLOW}WAYLO_WEBHOOK_URL not set. Enter it now (or press Ctrl+C to cancel):${NC}"
  read -r WAYLO_WEBHOOK_URL
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  WayloAI · E2E Webhook Test${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "📄 File:    ${FILE_PATH}"
echo -e "📤 Webhook: ${WAYLO_WEBHOOK_URL}"
echo ""

FILE_SIZE=$(du -h "$FILE_PATH" | cut -f1)
echo -e "📏 Size:    ${FILE_SIZE}"
echo ""

# Send request and measure time
START_TIME=$(date +%s)
echo -e "${YELLOW}⏳ Sending request...${NC}"

RESPONSE=$(curl -s -w "\n__STATUS__:%{http_code}\n__TIME__:%{time_total}" \
  -X POST \
  -F "file=@$FILE_PATH" \
  "$WAYLO_WEBHOOK_URL")

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Parse response
HTTP_STATUS=$(echo "$RESPONSE" | grep "__STATUS__" | cut -d':' -f2)
CURL_TIME=$(echo "$RESPONSE" | grep "__TIME__" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/__STATUS__/,$d')

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Response${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

if [ "$HTTP_STATUS" != "200" ]; then
  echo -e "${RED}✕ HTTP ${HTTP_STATUS}${NC}"
  echo ""
  echo "Response body:"
  echo "$BODY"
  exit 1
fi

echo -e "${GREEN}✓ HTTP 200 · ${ELAPSED}s${NC}"
echo ""

# Try to parse JSON and extract key fields
if command -v jq &> /dev/null; then
  REQUEST_ID=$(echo "$BODY" | jq -r '.request_id // "N/A"')
  TOUR_NAME=$(echo "$BODY" | jq -r '.tour_name // "N/A"')
  PAX=$(echo "$BODY" | jq -r '.pax // "N/A"')
  VEHICLE=$(echo "$BODY" | jq -r '.vehicle_type // "N/A"')
  DAYS_COUNT=$(echo "$BODY" | jq '.days | length')
  SEGMENTS_COUNT=$(echo "$BODY" | jq '[.days[].transfers[]] | length')
  CONFIDENCE=$(echo "$BODY" | jq -r '(.parsing_confidence * 100 | floor // 0) | tostring + "%"')
  PARSING_MS=$(echo "$BODY" | jq -r '.parsing_duration_ms // 0')
  DRIVERS_COUNT=$(echo "$BODY" | jq '.recommended_drivers | length')

  echo -e "  Request ID:    ${GREEN}${REQUEST_ID}${NC}"
  echo -e "  Tour name:     ${TOUR_NAME}"
  echo -e "  Pax:           ${PAX}"
  echo -e "  Vehicle:       ${VEHICLE}"
  echo -e "  Days:          ${DAYS_COUNT}"
  echo -e "  Segments:      ${SEGMENTS_COUNT}"
  echo -e "  AI confidence: ${CONFIDENCE}"
  echo -e "  Parsing time:  ${PARSING_MS}ms"
  echo -e "  Drivers found: ${DRIVERS_COUNT}"
  echo ""

  echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Test passed!${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
  echo ""

  echo -e "${YELLOW}Full JSON response saved to: /tmp/waylo-last-response.json${NC}"
  echo "$BODY" | jq '.' > /tmp/waylo-last-response.json
else
  echo -e "${YELLOW}(install 'jq' for pretty parsing)${NC}"
  echo ""
  echo "$BODY"
fi

echo ""
