"""
Priority-order resolution for authority auto-assignment and the reject cascade.

A category's authorities are ordered by the admin-set `priority_order` list in
`category_settings`; any authority not present in that list (e.g. just added) is
appended alphabetically. Resolving the order at read time means adding or deleting
an authority needs no bookkeeping in the settings doc — new ones fall to the end,
stale ids are simply skipped.
"""
from db import authorities_collection, category_settings_collection


def effective_order(category: str) -> list:
    """Return this category's authority docs in effective priority order."""
    authorities = list(authorities_collection.find({"category": category}))
    by_id = {str(a["_id"]): a for a in authorities}

    settings = category_settings_collection.find_one({"category": category}) or {}
    ranked, seen = [], set()
    for aid in settings.get("priority_order", []):
        a = by_id.get(aid)
        if a and aid not in seen:
            ranked.append(a)
            seen.add(aid)

    rest = sorted(
        (a for a in authorities if str(a["_id"]) not in seen),
        key=lambda a: (a.get("name") or "").lower(),
    )
    return ranked + rest


def next_authority(category: str, exclude_ids: set):
    """First authority in `category`'s effective order whose id is not excluded."""
    for a in effective_order(category):
        if str(a["_id"]) not in exclude_ids:
            return a
    return None


def is_auto_assign(category: str) -> bool:
    """Whether new complaints in `category` should be auto-assigned to the top authority."""
    settings = category_settings_collection.find_one({"category": category}) or {}
    return bool(settings.get("auto_assign"))
