#!/usr/bin/env python3
"""
Fix shop_items seed rows by adding the missing `is_non_veg` value.

Your OLD row format is:

1  id
2  name
3  barcode
4  sku_qr
5  category
6  price
7  discount_price
8  cost_price
9  stock_quantity
10 hsn_code
11 tax_rate
12 is_tax_inclusive
13 min_stock_alert
14 is_available
15 description
...

Your NEW format is:

14 is_available
15 is_non_veg
16 description
...

So this script inserts the boolean at position 15.

It only changes rows that have the OLD number of fields.
Rows already containing is_non_veg are left untouched.

Usage:
    python3 fix_shop_items_is_non_veg.py test.sql test_fixed.sql
"""

from pathlib import Path
import re
import sys


# Strong indicators that the product is non-vegetarian.
NON_VEG_KEYWORDS = {
    "non-veg",
    "non veg",
    "nonveg",
    "egg",
    "eggs",
    "chicken",
    "mutton",
    "fish",
    "prawn",
    "prawns",
    "shrimp",
    "seafood",
    "meat",
    "beef",
    "pork",
    "lamb",
    "keema",
    "kebab",
    "kabab",
    "salami",
    "sausage",
    "pepperoni",
    "tandoori chicken",
    "roasted chicken",
    "fried chicken",
}


def split_sql_values(body: str) -> list[str]:
    """
    Split a SQL tuple body on commas while respecting:
      - single-quoted strings
      - ARRAY[...]
      - JSON {...}
      - parentheses
    """
    values = []
    current = []
    quote = False
    depth = 0
    i = 0

    while i < len(body):
        ch = body[i]

        if quote:
            current.append(ch)

            # PostgreSQL escaped quote: ''
            if ch == "'":
                if i + 1 < len(body) and body[i + 1] == "'":
                    current.append(body[i + 1])
                    i += 2
                else:
                    quote = False

            i += 1
            continue

        if ch == "'":
            quote = True
            current.append(ch)

        elif ch in "([{":
            depth += 1
            current.append(ch)

        elif ch in ")]}":
            depth -= 1
            current.append(ch)

        elif ch == "," and depth == 0:
            values.append("".join(current).strip())
            current = []

        else:
            current.append(ch)

        i += 1

    if current:
        values.append("".join(current).strip())

    return values


def infer_is_non_veg(values: list[str]) -> bool:
    """
    Infer is_non_veg from the complete row.

    Explicit `non-veg` / `non veg` / `nonveg` wins.
    Then common animal-food keywords are checked.
    """

    text = " ".join(values).lower()

    # Strong explicit tag/description signal.
    if re.search(r"\bnon[- ]?veg\b", text):
        return True

    # Animal-food indicators.
    for keyword in NON_VEG_KEYWORDS:
        if re.search(
            r"(?<![a-z])" + re.escape(keyword) + r"(?![a-z])",
            text,
        ):
            return True

    return False


def process_file(input_path: Path, output_path: Path) -> None:
    sql = input_path.read_text(encoding="utf-8")

    fixed_rows = 0
    already_fixed = 0
    skipped = 0

    # A seed row normally starts with "(" and ends with "),"
    # or ")" on its own line.
    #
    # We process complete parenthesized tuples rather than doing a
    # dangerous simple comma replacement.
    result = []
    i = 0
    n = len(sql)

    while i < n:
        if sql[i] != "(":
            result.append(sql[i])
            i += 1
            continue

        # Find matching closing parenthesis while respecting SQL strings.
        start = i
        i += 1
        depth = 1
        quote = False

        while i < n and depth > 0:
            ch = sql[i]

            if quote:
                if ch == "'":
                    if i + 1 < n and sql[i + 1] == "'":
                        i += 2
                        continue
                    quote = False
            else:
                if ch == "'":
                    quote = True
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1

            i += 1

        if depth != 0:
            # Malformed/unclosed SQL. Preserve the remainder.
            result.append(sql[start:])
            break

        end = i
        body = sql[start + 1:end - 1]
        values = split_sql_values(body)

        # Your old rows contain 29 fields.
        # Your new rows contain 30 fields after adding is_non_veg.
        if len(values) == 29:
            # is_available is field #14.
            # Insert is_non_veg as field #15.
            is_non_veg = "true" if infer_is_non_veg(values) else "false"

            values.insert(14, is_non_veg)

            # Preserve the general formatting of the seed file.
            replacement = "(" + ", ".join(values) + ")"

            result.append(replacement)
            fixed_rows += 1

        elif len(values) == 30:
            # Already contains is_non_veg.
            result.append(sql[start:end])
            already_fixed += 1

        else:
            # Could be another SQL expression/tuple.
            result.append(sql[start:end])
            skipped += 1

    output_path.write_text("".join(result), encoding="utf-8")

    print()
    print("Done.")
    print(f"Input file:              {input_path}")
    print(f"Output file:             {output_path}")
    print(f"Rows fixed:              {fixed_rows}")
    print(f"Rows already containing: {already_fixed}")
    print(f"Other tuples skipped:    {skipped}")
    print()


def main():
    if len(sys.argv) != 3:
        print(
            "Usage:\n"
            "  python3 fix_shop_items_is_non_veg.py input.sql output.sql"
        )
        sys.exit(1)

    input_path = Path(sys.argv[1]).expanduser()
    output_path = Path(sys.argv[2]).expanduser()

    if not input_path.exists():
        print(f"ERROR: File not found: {input_path}")
        sys.exit(1)

    process_file(input_path, output_path)


if __name__ == "__main__":
    main()
