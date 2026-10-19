# Extract raw, maltster-native fields from Briess's <article class="product">
# markup (as emitted by `pup 'article.product json{}'`).
#
# Usage: pup 'article.product json{}' < products.html | jq -f bin/briess.jq

def trim: gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "");

def to_num:
  if type == "null" or . == "" then null else tonumber end;

def as_pct: gsub("%"; "") | to_num;

# First text node of a descendant whose class attribute matches.
def class_text($cls):
  [.. | objects | select(.class == $cls) | .text][0] // "";

# First text node of a descendant with the given tag.
def tag_text($tag):
  [.. | objects | select(.tag == $tag) | .text][0] // "";

# All <p> text under a descendant with the given class, joined.
def paragraphs($cls):
  [.. | objects | select(.class == $cls) | .. | objects | select(.tag == "p") | .text]
  | join("\n\n");

# Value text of the analysis box whose label matches the regex
# (e.g. "SRM", "Yield", "Fermentability").
def box_value($label_re):
  [.. | objects
    | select(any(.children[]?; .class == "label" and (.text | test($label_re))))
    | .children[]? | select(.class == "value") | .text][0] // "";

# Map each product card to one raw malt object.
[.[] | {
  name:           (class_text("product-title") | trim),
  slug:           .id,
  maltster:       "Briess",
  description:    (paragraphs("product-description") | trim),
  notes:          (tag_text("b") | trim),
  color_srm:      (box_value("SRM") | as_pct),
  yield_on_grind: (box_value("Yield") | as_pct),
  fermentability: (box_value("Fermentability") | as_pct)
}]
