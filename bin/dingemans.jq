# Extract raw, maltster-native fields from a single cached Dingemans page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        <h1>
#   - type:        fieldset.group-type (the linked taxonomy term)
#   - description: field-name-body paragraphs
#   - notes:       "Flavour" key specification
#   - particulars: #group-specs Drupal fields; "Lovibond" (decimal comma) and
#                  "Colour EBC" (fallback), "Extract fine D.M." (%).

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];
def norm: gsub(","; ".");

def h1_text: [.. | objects | select(.tag == "h1") | .. | objects | .text? // empty][0] // "";

# All Drupal field-name-field-* blocks as {label, value}.
def fields:
  [.. | objects | select((.class // "") | test("field-name-field-"))
   | {
       label: ([.children[]? | select((.class // "") == "field-label") | .text][0] // "" | trim),
       value: ([.. | objects | select((.class // "") == "field-item even") | .text][0] // "" | trim)
     }];

def fval($fields; $re):
  [$fields[] | select((.label // "") | test($re)) | .value][0] // "";

def description:
  [.. | objects | select((.class // "") | test("field-name-body"))
   | .. | objects | select(.tag == "p")
   | ([.. | objects | .text? // empty] | join(" ") | trim)
   | select(length > 0)]
  | join("\n\n");

def malt_type:
  [.. | objects | select((.class // "") | test("group-type"))
   | .. | objects | select(.tag == "a") | .text][0] // "";

(.[0]
  | . as $root
  | ($root | fields) as $f
  | (fval($f; "^Lovibond")) as $lov_text
  | (fval($f; "^Colour EBC")) as $ebc_text
  | (if $lov_text != "" then "lovibond" elif $ebc_text != "" then "ebc" else null end) as $unit
  | (if $unit == "lovibond" then $lov_text else $ebc_text end) as $color_text
  | {
      name:        ($root | h1_text | trim),
      slug:        $slug,
      maltster:    "Dingemans",
      category_hint: ($root | malt_type | trim),
      description: ($root | description),
      notes:       (fval($f; "^Flavour")),
      extract_pct: (fval($f; "^Extract") | norm | nums[0] | tonum),
      moisture_pct: (fval($f; "^Moisture") | norm | nums[0] | tonum),
      color_unit:  $unit,
      color_value: ($color_text | norm | nums[0] | tonum)
    })
