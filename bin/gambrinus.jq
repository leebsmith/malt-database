# Extract raw, maltster-native fields from a single cached Gambrinus page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        <h1>
#   - description: p.section-single-product__short-desc (short blurb; may be
#                  empty) -- when empty we fall back to the long description
#   - notes:       div.section-single-product__description (long prose)
#   - particulars: .section-single-product__spec key/value pairs, notably
#                  "Colour Lovibond" / "Colour SRM" / "Colour EBC" and
#                  "Extract FG Min" (%).
#     Prefer Lovibond, then SRM, then EBC.

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];

# Some elements keep their text in child spans, so collect descendant text.
def h1_text: [.. | objects | select(.tag == "h1") | .. | objects | .text? // empty][0] // "";

def short_desc:
  [.. | objects | select(.tag == "p" and (.class // "") == "section-single-product__short-desc")
   | ([.. | objects | .text? // empty] | join(" ") | trim) | select(length > 0)][0] // "";

def long_desc:
  [.. | objects | select((.class // "") == "section-single-product__description")
   | .. | objects | select(.tag == "p")
   | ([.. | objects | .text? // empty] | join(" ") | trim) | select(length > 0)]
  | join("\n\n");

# Each spec pair as {key, value}.
def specs:
  [.. | objects | select((.class // "") == "section-single-product__spec")
   | {
       key:   ([.. | objects | select((.class // "") == "section-single-product__spec-key") | .text][0] // "" | trim),
       value: ([.. | objects | select((.class // "") == "section-single-product__spec-value") | .text][0] // "" | trim)
     }];

(.[0]
  | . as $root
  | ($root | specs) as $specs
  | ([$specs[] | select((.key // "") | test("Colour Lovibond")) | .value][0] // "") as $lov
  | ([$specs[] | select((.key // "") | test("Colour SRM")) | .value][0] // "") as $srm
  | ([$specs[] | select((.key // "") | test("Colour EBC")) | .value][0] // "") as $ebc
  | ([$specs[] | select((.key // "") | test("Extract")) | .value][0] // "") as $extract_text
  | (if $lov != "" then "lovibond" elif $srm != "" then "srm" elif $ebc != "" then "ebc" else null end) as $unit
  | (if $unit == "lovibond" then $lov elif $unit == "srm" then $srm else $ebc end) as $color_text
  | ($root | short_desc) as $short
  | ($root | long_desc) as $long
  | {
      name:         ($root | h1_text | trim),
      slug:         $slug,
      maltster:     "Gambrinus",
      description:  (if $short != "" then $short else $long end),
      notes:        (if $short != "" then $long else "" end),
      extract_pct:  ($extract_text | nums[0] | tonum),
      moisture_pct: ([$specs[] | select((.key // "") | test("Moisture")) | .value][0] // "" | nums[0] | tonum),
      color_unit:   $unit,
      color_min:    ($color_text | nums[0] | tonum),
      color_max:    ($color_text | nums[-1] | tonum)
    })
