# Extract raw, maltster-native fields from a single cached Simpsons malt page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        the page's single <h1>
#   - description: the "#malt-page-intro" paragraphs with class "intro sm"
#   - particulars: the ASBC tab (#asbc table): "Extract % d.b" and
#                  "Colour ° Lovibond" (already Lovibond; range or single value)
#   - notes:       the flavour line in a ".substyles-list .links" <p>, excluding
#                  the packaging line ("Whole, Milled ...")

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");

def tonum: if . == null or . == "" then null else tonumber end;

# Text of the page's single <h1>.
def h1_text: [.. | objects | select(.tag == "h1") | .text][0] // "";

def description_text:
  [.. | objects | select((.id // "") == "malt-page-intro")
   | .. | objects | select(.tag == "p" and .class == "intro sm") | .text]
  | join("\n\n") | trim;

# ASBC table rows as arrays of cell text (recurses into value spans).
def asbc_rows:
  [.. | objects | select((.id // "") == "asbc")
   | .. | objects | select(.tag == "tr")
   | [.. | objects | .text? // empty | select(length > 0)]];

def notes_text:
  [.. | objects | select(.tag == "div" and .class == "links")
   | .children[]? | select(.tag == "p")
   | (.text // "" | trim)
   | select(length > 0)
   | select((test("Whole|Milled")) | not)][0] // "";

(.[0]
  | . as $root
  | ($root | asbc_rows) as $rows
  | ([$rows[] | select((.[0] // "") | test("Colour")) | .[1:]][0] // []) as $color
  | {
      name:               ($root | h1_text | trim),
      slug:               $slug,
      maltster:           "Simpsons",
      description:        ($root | description_text),
      notes:              ($root | notes_text),
      extract_pct:        (([$rows[] | select((.[0] // "") | test("Extract")) | .[1]][0]) | tonum),
      color_lovibond_min: (($color[0]) | tonum),
      color_lovibond_max: (($color[-1]) | tonum)
    })
