# Extract raw, maltster-native fields from a single cached Great Western page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        h1.name
#   - description: p.description
#   - notes:       p.additional
#   - particulars: div.stats-table p.attribute (span.title + value), notably
#                  "Color SRM".

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];

def h1_text:
  [.. | objects | select(.tag == "h1" and (.class // "") == "name")
   | .. | objects | .text? // empty][0] // "";

def para_text($cls):
  [.. | objects | select(.tag == "p" and (.class // "") == $cls)
   | ([.. | objects | .text? // empty] | join(" ") | trim)][0] // "";

def attrs:
  [.. | objects | select(.tag == "p" and (.class // "") == "attribute")
   | {
       key:   ([.. | objects | select((.class // "") == "title") | .text][0] // "" | trim),
       value: (.text // "" | trim)
     }];

(.[0]
  | . as $root
  | ($root | attrs) as $a
  | ([$a[] | select((.key // "") | test("Color SRM")) | .value][0] // "") as $color_text
  | ([$a[] | select((.key // "") | test("Extract")) | .value][0] // "") as $extract_text
  | {
      name:        ($root | h1_text | trim),
      slug:        $slug,
      maltster:    "Great Western",
      description: ($root | para_text("description")),
      notes:       ($root | para_text("additional")),
      extract_pct: ($extract_text | nums[0] | tonum),
      moisture_pct: ([$a[] | select((.key // "") | test("Moisture")) | .value][0] // "" | nums[0] | tonum),
      color_unit:  (if $color_text != "" then "srm" else null end),
      color_min:   ($color_text | nums[0] | tonum),
      color_max:   ($color_text | nums[-1] | tonum)
    })
