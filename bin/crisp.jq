# Extract raw, maltster-native fields from a single cached Crisp page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        section.breadcrumb h1
#   - notes:       .malt-post__tasting list items (h3 "Tasting Notes" + ul)
#   - description: .malt-post__text <p> paragraphs
#   - particulars: .malt-post__table <table> with Parameter / IoB / EBC / ASBC
#                  columns. Table shape varies:
#                    * prefer a cell containing "°L" (Lovibond) for colour
#                    * else the last cell containing "EBC"
#                    * extract: last cell containing "%", else "L°/kg" (/3.866)
#   - sold_out:    title <img> whose alt/src contains "Sold Out".

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");
def tonum: if . == null or . == "" then null else tonumber end;
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];
def norm: gsub(","; ".");

def name_text:
  [.. | objects | select(.tag == "section" and ((.class // "") | test("breadcrumb")))
   | .. | objects | select(.tag == "h1") | .. | objects | .text? // empty][0] // "";

def notes:
  [.. | objects | select((.class // "") | test("malt-post__tasting"))
   | .. | objects | select(.tag == "li")
   | ([.. | objects | .text? // empty] | join(" ") | trim)
   | select(length > 0)]
  | join("; ");

def description:
  [.. | objects | select((.class // "") | test("malt-post__text"))
   | .. | objects | select(.tag == "p")
   | ([.. | objects | .text? // empty] | join(" ") | trim)
   | select(length > 0)]
  | join("\n\n");

def rows:
  [.. | objects | select(.tag == "table")
   | .. | objects | select(.tag == "tr")
   | [.. | objects | select(.tag == "td" or .tag == "th")
      | ([.. | objects | .text? // empty] | join(" ") | trim)]];

def row_cells($rows; $re):
  [$rows[] | select((.[0] // "") | test($re))][0] // [];

def sold_out:
  [.. | objects | select(.tag == "img" and ((.class // "") | test("malt-post__title")))
   | (((.alt // "") + " " + (.src // "") + " " + (."data-src" // ""))
      | ascii_downcase | test("sold.?out"))]
  | any;

(.[0]
  | . as $root
  | ($root | rows) as $rows
  | (row_cells($rows; "^Colour")) as $crow
  | (row_cells($rows; "^Extract")) as $erow
  | ([$crow[] | select(test("°L"))] | .[0]) as $lov_cell
  | ([$crow[] | select(test("EBC"))] | .[-1]) as $ebc_cell
  | (if $lov_cell != null then $lov_cell elif $ebc_cell != null then $ebc_cell else null end) as $color_cell
  | ([$erow[] | select(test("%"))] | .[-1]) as $pct_cell
  | ([$erow[] | select(test("L°/kg"))] | .[-1]) as $ldk_cell
  | {
      name:        ($root | name_text | trim),
      slug:        $slug,
      maltster:    "Crisp",
      description: ($root | description),
      notes:       ($root | notes),
      sold_out:    ($root | sold_out),
      extract_pct: (if $pct_cell != null then ($pct_cell | norm | nums[0] | tonum)
                    elif $ldk_cell != null then (($ldk_cell | norm | nums[0] | tonum) / 3.866)
                    else null end),
      color_unit:  (if $lov_cell != null then "lovibond" elif $ebc_cell != null then "ebc" else null end),
      color_min:   (($color_cell // "") | norm | nums[0] | tonum),
      color_max:   (($color_cell // "") | norm | nums[-1] | tonum)
    })
