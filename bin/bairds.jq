# Extract raw, maltster-native fields from a single cached Bairds malt page.
#
# Input: `pup 'html json{}'` (an array with one <html> element), plus the
# slug passed via `jq --arg slug ...`.
#
# Layout relied upon:
#   - name:        the page's single <h1> inside .et_pb_text_inner
#   - description: the .et_pb_text_inner paragraph immediately after the name
#   - notes:       the "Flavour profile:" <p> (<mark> label + text)
#   - particulars: the ASBC tab (.et_pb_tab_2): "Extract ... % min" and
#                  "Colour ... °SRM" (a range, e.g. "1.0 – 2.0")

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");

# All numeric literals in a string, in order (e.g. "1.0 – 2.0" -> [1.0, 2.0]).
def nums: [scan("[0-9]+(?:\\.[0-9]+)?") | tonumber];

# Text of the page's single <h1>.
def h1_text: [.. | objects | select(.tag == "h1") | .text][0] // "";

# Ordered text content of every .et_pb_text_inner element.
def text_inner_texts:
  [.. | objects | select(.class == "et_pb_text_inner")]
  | map([.. | objects | .text? // empty] | join(" ") | trim);

# Value text of a <p> whose <mark> child matches the regex
# (used for "Flavour profile:", "Suggested Use:", etc.).
def detail($re):
  [.. | objects | select(.tag == "p")
    | select(any(.children[]?; .tag == "mark" and ((.text // "") | test($re))))
    | .text][0] // "";

# Value text of a <p> inside the ASBC tab whose <strong> matches the regex
# (used for "Extract", "Colour").
def tab_value($re):
  [.. | objects | select((.class // "") | contains("et_pb_tab_2"))
    | .. | objects | select(.tag == "p")
    | select(any(.children[]?; .tag == "strong" and ((.text // "") | test($re))))
    | .text][0] // "";

(.[0] | . as $root
  | ($root | h1_text) as $name
  | ($root | text_inner_texts) as $texts
  | ($root | tab_value("Colour") | nums) as $color
  | {
      name:           ($name | trim),
      slug:           $slug,
      maltster:       "Bairds",
      description:    (($texts[($texts | index($name)) + 1] // "") | trim),
      notes:          ($root | detail("Flavour profile") | trim),
      extract_pct:    ($root | tab_value("Extract") | nums[0] // null),
      color_srm_min:  ($color[0] // null),
      color_srm_max:  ($color[-1] // null)
    })
