# Extract raw, maltster-native fields from a single cached Canada Malting page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        div.product-details h1
#   - type:        div.product-details h3 (category hint)
#   - description: div.product-details p paragraphs
#   - particulars: .product-table-row (strong label + span.product-data),
#                  notably "Colour °L" (fallback "Colour SRM") and "Extract %".

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];
def norm: gsub(","; ".");

def details: [.. | objects | select((.class // "") | test("product-details"))];

def name_text:
  [details[] | .. | objects | select(.tag == "h1") | .. | objects | .text? // empty][0] // "";

def type_text:
  [details[] | .. | objects | select(.tag == "h3") | .. | objects | .text? // empty][0] // "";

def description:
  [details[] | .. | objects | select(.tag == "p")
   | ([.. | objects | .text? // empty] | join(" ") | trim) | select(length > 0)]
  | join("\n\n");

def rows:
  [.. | objects | select((.class // "") == "product-table-row")
   | {
       label: ([.. | objects | select(.tag == "strong") | .text][0] // "" | trim),
       value: ([.. | objects | select((.class // "") == "product-data") | .text][0] // "" | trim)
     }];

def rval($rows; $re):
  [$rows[] | select((.label // "") | test($re)) | .value][0] // "";

(.[0]
  | . as $root
  | ($root | rows) as $r
  | (rval($r; "°L")) as $lov
  | (rval($r; "SRM")) as $srm
  | (if $lov != "" then "lovibond" elif $srm != "" then "srm" else null end) as $unit
  | (if $lov != "" then $lov else $srm end) as $color_text
  | {
      name:          ($root | name_text | trim),
      slug:          $slug,
      maltster:      "Canada Malting",
      category_hint: ($root | type_text | trim),
      description:   ($root | description),
      extract_pct:   (rval($r; "^Extract") | norm | nums[0] | tonum),
      moisture_pct:  (rval($r; "Moisture") | norm | nums[0] | tonum),
      color_unit:    $unit,
      color_min:     ($color_text | norm | nums[0] | tonum),
      color_max:     ($color_text | norm | nums[-1] | tonum)
    })
