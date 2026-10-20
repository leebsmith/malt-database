# Extract raw, maltster-native fields from a single cached Bestmalz page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        h1 inside div.kt-inside-inner-col
#   - description: sibling div.*-dynamichtml elements after the h1
#   - particulars: div.kt-inside-inner-col table (Parameter / Minimum / Maximum
#                  / Einheit). "Wort color" gives "EBC / L" values, e.g.
#                  "3.0 / 1.6" -> Lovibond 1.6; "Extract ..." gives %.
#     European decimal commas are normalized to dots.

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];
def norm: gsub(","; ".");

def h1_col:
  [.. | objects
   | select(.tag == "div" and ((.class // "") | contains("kt-inside-inner-col"))
            and (([.. | objects | select(.tag == "h1")] | length) > 0))][0];

def description:
  (h1_col | .children // [])
  | map(select(.tag == "div" and ((.class // "") | contains("dynamichtml"))))
  | map([.. | objects | .text? // empty] | join(" ") | trim)
  | map(select(length > 0))
  | join("\n\n");

def rows:
  [.. | objects | select(.tag == "tr")
   | [.. | objects | select(.tag == "td" or .tag == "th")
      | ([.. | objects | .text? // empty] | join(" ") | trim)]];

# Colour cell "EBC / L" -> the Lovibond part (after "/"); pure values kept.
def colour_value($c):
  ($c // "" | norm) as $s
  | (if ($s | test("/")) then ($s | split("/") | last) else $s end)
  | [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber][0];

(.[0]
  | . as $root
  | ($root | rows) as $rows
  | ([$rows[] | select((.[0] // "") | test("Extract"))][0] // []) as $er
  | ([$rows[] | select((.[0] // "") | test("Wort color|Wort Color|Colour|Color"))][0] // []) as $cr
  | (($er[1] // "") | norm | nums[0] | tonum) as $extract
  | (if (($cr | length) >= 4) then ($cr[2] // $cr[1]) else $cr[1] end) as $cmax_cell
  | {
      name:        ($root | ([.. | objects | select(.tag == "h1") | .. | objects | .text? // empty][0] // "") | trim),
      slug:        $slug,
      maltster:    "Bestmalz",
      description: ($root | description),
      extract_pct: $extract,
      moisture_pct: ([$rows[] | select((.[0] // "") | test("Moisture")) | .[1:] | .[] | select(test("[0-9]"))][0] // "" | norm | nums[0] | tonum),
      color_unit:  (if $cr == [] then null
                    elif (($cr[1] // "") | test("/")) then "lovibond"
                    else "ebc" end),
      color_min:   (colour_value($cr[1]) // null),
      color_max:   (colour_value($cmax_cell) // null)
    })
