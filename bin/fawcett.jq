# Extract raw, maltster-native fields from a single cached Fawcett malt page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug/category passed via `jq --arg slug ... --arg category ...`.
#
# Layout relied upon:
#   - name:        the page's single <h1>
#   - notes:       the "wp-block-heading" <h3> (short flavour summary)
#   - description: any "wp-block-paragraph" <p> in .about-section (may be absent)
#   - particulars: three tabs (IOB / EBC / ASBC), each a table.spec-table:
#       #tabs-content-3 = ASBC ("ASBC Colour Lovibond", "Extract Course")
#       #tabs-content-2 = EBC  ("Colour EBC", "Extract Course")
#       #tabs-content-1 = IOB  ("IOB Colour EBC", "Extract Ltr /kg") — fallback
#     Prefer ASBC (Lovibond); fall back to EBC, then IOB (LDK converted to %).

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];

def h1_text: [.. | objects | select(.tag == "h1") | .. | objects | .text? // empty][0] // "";

def about: [.. | objects | select((.class // "") == "about-section")];

def notes_text:
  [about[] | .. | objects | select(.tag == "h3" and (.class // "") == "wp-block-heading") | .text][0] // "";

def description_text:
  [about[] | .. | objects | select(.tag == "p" and (.class // "") == "wp-block-paragraph") | .text]
  | join("\n\n") | trim;

# Rows of the tab with the given id, as arrays of cell text (recurses into
# the value cells).
def tab_rows($id):
  [.. | objects | select((.id // "") == $id)
   | .. | objects | select(.tag == "tr")
   | [.. | objects | .text? // empty | select(length > 0)]];

(.[0]
  | . as $root
  | ($root | tab_rows("tabs-content-3")) as $asbc
  | ($root | tab_rows("tabs-content-2")) as $ebc
  | ($root | tab_rows("tabs-content-1")) as $iob
  | (([$asbc[] | select((join(" ")) | test("Lovibond"))] | length) > 0) as $has_asbc
  | (([$ebc[] | select((join(" ")) | test("Extract Course"))] | length) > 0) as $has_ebc
  | (if $has_asbc then $asbc elif $has_ebc then $ebc else $iob end) as $rows
  | ([$rows[] | select((join(" ")) | test("Extract Course")) | join(" ")][0] // "") as $extract_pct_text
  | ([$rows[] | select((join(" ")) | test("Extract Ltr")) | join(" ")][0] // "") as $extract_ldk_text
  | ([$rows[] | select((join(" ")) | test("Lovibond|Colour EBC")) | join(" ")][0] // "") as $color_text
  | {
      name:          ($root | h1_text | trim),
      slug:          $slug,
      maltster:      "Fawcett",
      category_hint: $category,
      description:   ($root | description_text),
      notes:         ($root | notes_text | trim),
      extract_pct:   (
        if $has_asbc or $has_ebc then ($extract_pct_text | nums[0] | tonum)
        elif $extract_ldk_text != "" then (($extract_ldk_text | nums[0] | tonum) / 3.866)
        else null end
      ),
      color_unit:    (if $has_asbc then "lovibond"
                      elif ($has_ebc or ($iob | length) > 0) then "ebc"
                      else null end),
      color_min:     ($color_text | nums[0] | tonum),
      color_max:     ($color_text | nums[-1] | tonum)
    })
