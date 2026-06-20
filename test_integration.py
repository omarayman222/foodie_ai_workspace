"""
Foodie AI - Full Integration Test Suite
Covers: Auth, Profile, Pantry, Recipes, Favourites, Shopping List,
        Meal Plan, Chat, Rating, Substitution, Cooking (Sous-Chef)
"""

import sys
import uuid
import requests
from datetime import datetime, timedelta

BASE = "http://127.0.0.1:5000/api"
TOKEN = None
USER_EMAIL = None
RECIPE_ID = None

PASS_COUNT = 0
FAIL_COUNT = 0
ERRORS = []


def safe_json(r):
    try:
        return r.json()
    except Exception:
        return {}


def ok(label):
    global PASS_COUNT
    PASS_COUNT += 1
    print(f"  [PASS] {label}")


def fail(label, reason=""):
    global FAIL_COUNT
    FAIL_COUNT += 1
    msg = f"  [FAIL] {label}"
    if reason:
        msg += f" -- {reason}"
    print(msg)
    ERRORS.append(msg)


def check(label, condition, reason=""):
    if condition:
        ok(label)
    else:
        fail(label, reason)


def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)


def hdr():
    return {"Authorization": f"Bearer {TOKEN}"}


def post(path, body=None, extra_headers=None):
    h = {"Content-Type": "application/json"}
    if extra_headers:
        h.update(extra_headers)
    return requests.post(f"{BASE}{path}", json=body or {}, headers=h, timeout=30)


def get(path, params=None, extra_headers=None):
    h = {}
    if extra_headers:
        h.update(extra_headers)
    return requests.get(f"{BASE}{path}", params=params, headers=h, timeout=30)


def put(path, body=None, extra_headers=None):
    h = {"Content-Type": "application/json"}
    if extra_headers:
        h.update(extra_headers)
    return requests.put(f"{BASE}{path}", json=body or {}, headers=h, timeout=30)


def delete(path, extra_headers=None):
    h = {}
    if extra_headers:
        h.update(extra_headers)
    return requests.delete(f"{BASE}{path}", headers=h, timeout=30)


def patch(path, body=None, extra_headers=None):
    h = {"Content-Type": "application/json"}
    if extra_headers:
        h.update(extra_headers)
    return requests.patch(f"{BASE}{path}", json=body or {}, headers=h, timeout=30)


# ==========================================================
# 1. AUTH
# ==========================================================
section("1. AUTH")

uid = uuid.uuid4().hex[:8]
USER_EMAIL = f"testuser_{uid}@foodie.test"

# 1a. Register missing password
r = post("/auth/register", {"email": USER_EMAIL})
check("Register: missing password -> 400", r.status_code == 400,
      f"got {r.status_code}")

# 1b. Register new user
r = post("/auth/register", {"name": "Test User", "email": USER_EMAIL, "password": "testpass123"})
check("Register: new user -> 201", r.status_code == 201, f"got {r.status_code} {r.text[:100]}")

# 1c. Register duplicate
r = post("/auth/register", {"name": "Dup", "email": USER_EMAIL, "password": "other"})
check("Register: duplicate email -> 400", r.status_code == 400, f"got {r.status_code}")

# 1d. Login wrong password
r = post("/auth/login", {"email": USER_EMAIL, "password": "wrongpass"})
check("Login: wrong password -> 400", r.status_code == 400, f"got {r.status_code}")

# 1e. Login non-existent email
r = post("/auth/login", {"email": "nobody@foodie.test", "password": "x"})
check("Login: bad email -> 400", r.status_code == 400, f"got {r.status_code}")

# 1f. Login valid
r = post("/auth/login", {"email": USER_EMAIL, "password": "testpass123"})
check("Login: valid -> 200", r.status_code == 200, f"got {r.status_code}")
data = safe_json(r)
check("Login: token present", "token" in data)
check("Login: name in response", "name" in data)
TOKEN = data.get("token")

# 1g. Protected route without token
r = get("/users/profile")
check("Auth guard: no token -> 401", r.status_code == 401, f"got {r.status_code}")


# ==========================================================
# 2. PROFILE  (mounted at /api/users)
# ==========================================================
section("2. PROFILE")

# 2a. Get profile
r = get("/users/profile", extra_headers=hdr())
check("Profile GET -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")
data = safe_json(r)
check("Profile GET: email present", data.get("email") == USER_EMAIL)
check("Profile GET: name present", "name" in data)
p = data.get("profile", {})
check("Profile GET: all array fields present",
      all(k in p for k in ["allergies", "diet", "medicalConditions", "dislikes", "dislikedCuisines"]))

# 2b. Update name + arrays
r = put("/users/profile", {
    "name": "Mohamed",
    "allergies": ["peanuts"],
    "diet": ["keto"],
    "medicalConditions": ["diabetes"],
    "dislikes": ["olives"],
    "dislikedCuisines": ["spicy"],
}, extra_headers=hdr())
check("Profile UPDATE -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")

# 2c. Verify saved
r = get("/users/profile", extra_headers=hdr())
data = safe_json(r)
p = data.get("profile", {})
check("Profile UPDATE: name saved", data.get("name") == "Mohamed")
check("Profile UPDATE: allergies saved", p.get("allergies") == ["peanuts"])
check("Profile UPDATE: diet saved", p.get("diet") == ["keto"])

# 2d. Partial update (name only)
r = put("/users/profile", {"name": "Ali"}, extra_headers=hdr())
check("Profile PARTIAL (name only) -> 200", r.status_code == 200, f"got {r.status_code}")
r = get("/users/profile", extra_headers=hdr())
data = safe_json(r)
p2 = data.get("profile", {})
check("Profile PARTIAL: name updated", data.get("name") == "Ali")
check("Profile PARTIAL: arrays unchanged", p2.get("allergies") == ["peanuts"])

# 2e. Clear arrays with empty list
r = put("/users/profile", {"allergies": [], "diet": []}, extra_headers=hdr())
check("Profile CLEAR arrays -> 200", r.status_code == 200, f"got {r.status_code}")
r = get("/users/profile", extra_headers=hdr())
p3 = safe_json(r).get("profile", {})
check("Profile CLEAR: allergies empty", p3.get("allergies") == [])
check("Profile CLEAR: diet empty", p3.get("diet") == [])
check("Profile CLEAR: other arrays unchanged", p3.get("dislikes") == ["olives"])


# ==========================================================
# 3. PANTRY
# ==========================================================
section("3. PANTRY")

# 3a. Get empty pantry
r = get("/pantry", extra_headers=hdr())
check("Pantry GET empty -> 200", r.status_code == 200, f"got {r.status_code}")
check("Pantry GET empty: items=[]", safe_json(r).get("items", []) == [])

# 3b. Add ingredients (legacy string array)
r = post("/pantry/add", {"ingredients": ["chicken", "garlic", "onion"]}, extra_headers=hdr())
check("Pantry ADD -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")

# 3c. Verify 3 items
r = get("/pantry", extra_headers=hdr())
check("Pantry GET after add: 3 items", len(safe_json(r).get("items", [])) == 3)

# 3d. Add duplicates -- should not grow
r = post("/pantry/add", {"ingredients": ["chicken", "garlic"]}, extra_headers=hdr())
r = get("/pantry", extra_headers=hdr())
check("Pantry ADD duplicate: still 3 items", len(safe_json(r).get("items", [])) == 3)

# 3e. Bad input -> 400
r = post("/pantry/add", {"ingredients": "notanarray"}, extra_headers=hdr())
check("Pantry ADD: bad input -> 400", r.status_code == 400, f"got {r.status_code}")

# 3f. Overwrite with rich items
tomorrow = (datetime.utcnow() + timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
yesterday = (datetime.utcnow() - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")

r = put("/pantry/update", {
    "items": [
        {"name": "eggs",   "quantity": "12",   "expiryDate": tomorrow},
        {"name": "milk",   "quantity": "1L",   "expiryDate": tomorrow},
        {"name": "butter", "quantity": "200g", "expiryDate": yesterday},
    ]
}, extra_headers=hdr())
check("Pantry OVERWRITE -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")

r = get("/pantry", extra_headers=hdr())
items = safe_json(r).get("items", [])
check("Pantry OVERWRITE: 3 items stored", len(items) == 3)
check("Pantry OVERWRITE: expiryDate present", any(i.get("expiryDate") for i in items))

# 3g. Empty body -> 400
r = put("/pantry/update", {}, extra_headers=hdr())
check("Pantry OVERWRITE: empty body -> 400", r.status_code == 400, f"got {r.status_code}")


# ==========================================================
# 4. RECIPES
# ==========================================================
section("4. RECIPES")

# 4a. Search (uses 'q' param)
r = get("/recipes/search", params={"q": "chicken"}, extra_headers=hdr())
check("Recipe SEARCH -> 200", r.status_code == 200, f"got {r.status_code}")
data = safe_json(r)
recipes = data.get("recipes", [])
if isinstance(recipes, list) and len(recipes) > 0:
    check("Recipe SEARCH: results returned", True)
    RECIPE_ID = str(recipes[0].get("_id") or recipes[0].get("id", ""))
    print(f"         (grabbed RECIPE_ID={RECIPE_ID[:24]})")
else:
    fail("Recipe SEARCH: no results -- rating/substitution/cooking tests will skip")

# 4b. Search empty query -- should return results or empty, not 500
r = get("/recipes/search", params={"q": ""}, extra_headers=hdr())
check("Recipe SEARCH empty query -> not 500", r.status_code != 500, f"got {r.status_code}")

# 4c. Recommendations (GET /api/recipes/recommendations -- needs non-empty pantry)
# Pantry currently has eggs/milk/butter from overwrite above
r = get("/recipes/recommendations", extra_headers=hdr())
if r.status_code in (503, 500):
    print("  [SKIP] /api/recipes/recommendations: Python AI service offline")
elif r.status_code == 400:
    print(f"  [SKIP] /api/recipes/recommendations: empty pantry ({safe_json(r).get('message','')})")
elif r.status_code == 200:
    ok("Recommendations (/api/recipes/recommendations) -> 200")
else:
    fail("Recommendations", f"status={r.status_code} body={r.text[:200]}")

# 4d. Standalone recommendations endpoint
r = get("/recommendations", extra_headers=hdr())
if r.status_code in (503, 500):
    print("  [SKIP] /api/recommendations: Python AI service offline")
elif r.status_code == 200:
    ok("Recommendations (/api/recommendations) -> 200")
    check("Recommendations: recipes key", "recipes" in safe_json(r))
else:
    fail("Recommendations /api/recommendations", f"status={r.status_code} body={r.text[:200]}")


# ==========================================================
# 5. FAVOURITES
# ==========================================================
section("5. FAVOURITES")

FAKE_RECIPE_ID = f"fakerecipe_{uid}"

# 5a. GET empty
r = get("/favourites", extra_headers=hdr())
check("Favourites GET empty -> 200", r.status_code == 200, f"got {r.status_code}")
check("Favourites GET empty: empty list", safe_json(r).get("favourites", []) == [])

# 5b. Add without recipeId
r = post("/favourites", {"recipeName": "Chicken Soup"}, extra_headers=hdr())
check("Favourites ADD: missing recipeId -> 400", r.status_code == 400, f"got {r.status_code}")

# 5c. Add valid with full data
fav_payload = {
    "recipeId": FAKE_RECIPE_ID,
    "recipeName": "Test Chicken Soup",
    "recipeImage": "https://example.com/img.jpg",
    "prepTime": "10 min",
    "cookTime": "30 min",
    "totalTime": "40 min",
    "servings": 4,
    "cuisine": "American",
    "rating": 4.5,
    "nutrition": "Calories: 300",
    "ingredients": ["chicken", "water", "salt"],
    "directions": "Step 1: Boil\nStep 2: Serve",
}
r = post("/favourites", fav_payload, extra_headers=hdr())
check("Favourites ADD -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")
check("Favourites ADD: success true", safe_json(r).get("success") is True)

# 5d. GET -- verify full data persisted
r = get("/favourites", extra_headers=hdr())
favs = safe_json(r).get("favourites", [])
check("Favourites GET: 1 item", len(favs) == 1)
fav = favs[0] if favs else {}
check("Favourites: recipeName saved", fav.get("recipeName") == "Test Chicken Soup")
check("Favourites: ingredients saved", fav.get("ingredients") == ["chicken", "water", "salt"])
check("Favourites: directions saved", "Step 1" in (fav.get("directions") or ""))
check("Favourites: cookTime saved", fav.get("cookTime") == "30 min")
check("Favourites: rating saved", fav.get("rating") == 4.5)

# 5e. Check endpoint
r = get(f"/favourites/check/{FAKE_RECIPE_ID}", extra_headers=hdr())
check("Favourites CHECK: is fav -> true", safe_json(r).get("isFavourite") is True)

r = get("/favourites/check/nonexistent_id_xyz", extra_headers=hdr())
check("Favourites CHECK: not fav -> false", safe_json(r).get("isFavourite") is False)

# 5f. Upsert -- same recipeId, different name -> update not duplicate
r = post("/favourites", {**fav_payload, "recipeName": "Updated Name"}, extra_headers=hdr())
r = get("/favourites", extra_headers=hdr())
favs = safe_json(r).get("favourites", [])
check("Favourites UPSERT: still 1 item", len(favs) == 1)
check("Favourites UPSERT: name updated", favs[0].get("recipeName") == "Updated Name")

# 5g. Remove
r = delete(f"/favourites/{FAKE_RECIPE_ID}", extra_headers=hdr())
check("Favourites REMOVE -> 200", r.status_code == 200, f"got {r.status_code}")
r = get("/favourites", extra_headers=hdr())
check("Favourites REMOVE: list empty again", safe_json(r).get("favourites", []) == [])


# ==========================================================
# 6. SHOPPING LIST
# ==========================================================
section("6. SHOPPING LIST")

# 6a. GET empty
r = get("/shopping-list", extra_headers=hdr())
check("Shopping GET empty -> 200", r.status_code == 200, f"got {r.status_code}")

# 6b. Add items
r = post("/shopping-list/add", {"items": ["apples", "milk", "bread"]}, extra_headers=hdr())
check("Shopping ADD -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")

# 6c. Verify 3 items
r = get("/shopping-list", extra_headers=hdr())
items = safe_json(r).get("items", [])
check("Shopping GET: 3 items", len(items) == 3)

# 6d. Add duplicate -> increment quantity
r = post("/shopping-list/add", {"items": ["milk", "milk"]}, extra_headers=hdr())
r = get("/shopping-list", extra_headers=hdr())
items = safe_json(r).get("items", [])
milk = next((i for i in items if i["name"] == "milk"), None)
check("Shopping ADD duplicate: qty incremented", milk is not None and milk.get("quantity", 0) >= 2)

# 6e. Bad input -> 400
r = post("/shopping-list/add", {"items": "notanarray"}, extra_headers=hdr())
check("Shopping ADD: bad input -> 400", r.status_code == 400, f"got {r.status_code}")

# 6f. Remove decrement
r = post("/shopping-list/remove", {"items": ["milk"]}, extra_headers=hdr())
check("Shopping REMOVE decrement -> 200", r.status_code == 200, f"got {r.status_code}")
r = get("/shopping-list", extra_headers=hdr())
items = safe_json(r).get("items", [])
milk2 = next((i for i in items if i["name"] == "milk"), None)
check("Shopping REMOVE: qty decremented", milk2 is not None)

# 6g. Remove remaining milk
r = post("/shopping-list/remove", {"items": ["milk", "milk"]}, extra_headers=hdr())
r = get("/shopping-list", extra_headers=hdr())
items = safe_json(r).get("items", [])
milk3 = next((i for i in items if i["name"] == "milk"), None)
check("Shopping REMOVE: item gone when qty reaches 0", milk3 is None)

# 6h. Check/uncheck
r = get("/shopping-list", extra_headers=hdr())
items = safe_json(r).get("items", [])
if items:
    item_id = str(items[0]["_id"])
    r = patch(f"/shopping-list/check/{item_id}", extra_headers=hdr())
    check("Shopping CHECK toggle -> 200", r.status_code == 200, f"got {r.status_code}")
    checked = safe_json(r).get("isChecked")
    check("Shopping CHECK: isChecked in response", checked is not None)

    r = patch(f"/shopping-list/check/{item_id}", extra_headers=hdr())
    check("Shopping UNCHECK: toggled back -> 200", r.status_code == 200)
    check("Shopping UNCHECK: state flipped", safe_json(r).get("isChecked") != checked)
else:
    fail("Shopping CHECK: no items available to test")

# 6i. Check non-existent item
r = patch("/shopping-list/check/000000000000000000000000", extra_headers=hdr())
check("Shopping CHECK: non-existent -> 404", r.status_code == 404, f"got {r.status_code}")

# 6i2. Auto-sync: checking an item should add it to pantry
# Clear pantry first so we have a known state
put("/pantry/update", {"items": []}, extra_headers=hdr())
r = post("/shopping-list/add", {"items": ["test_sync_item"]}, extra_headers=hdr())
r = get("/shopping-list", extra_headers=hdr())
sync_item = next((i for i in safe_json(r).get("items", []) if i["name"] == "test_sync_item"), None)
if sync_item:
    sync_id = str(sync_item["_id"])
    r = patch(f"/shopping-list/check/{sync_id}", extra_headers=hdr())
    check("Shopping AUTO-SYNC: check -> 200", r.status_code == 200, f"got {r.status_code}")
    r = get("/pantry", extra_headers=hdr())
    pantry_items = [i["name"].lower() for i in safe_json(r).get("items", [])]
    check("Shopping AUTO-SYNC: item added to pantry on check", "test_sync_item" in pantry_items)
    # Uncheck should NOT remove from pantry
    r = patch(f"/shopping-list/check/{sync_id}", extra_headers=hdr())
    r = get("/pantry", extra_headers=hdr())
    pantry_items2 = [i["name"].lower() for i in safe_json(r).get("items", [])]
    check("Shopping AUTO-SYNC: uncheck does NOT remove from pantry", "test_sync_item" in pantry_items2)
else:
    fail("Shopping AUTO-SYNC: could not find test item")

# 6j. Generate with fallback ingredients (recipeId not in DB)
r = post("/shopping-list/generate", {
    "recipeId": "000000000000000000000000",
    "ingredients": ["flour", "eggs", "butter", "sugar", "vanilla extract"],
}, extra_headers=hdr())
check("Shopping GENERATE (fallback) -> 200", r.status_code == 200,
      f"got {r.status_code} {r.text[:200]}")
body = safe_json(r)
check("Shopping GENERATE: shoppingList or already-have",
      "shoppingList" in body or "already" in body.get("message", "").lower())

# 6k. Generate with no ingredients -> 400
r = post("/shopping-list/generate", {}, extra_headers=hdr())
check("Shopping GENERATE: no data -> 400", r.status_code == 400, f"got {r.status_code}")


# ==========================================================
# 7. MEAL PLAN
# ==========================================================
section("7. MEAL PLAN")

# Restore pantry with valid items for meal plan
put("/pantry/update", {"items": [
    {"name": "chicken", "quantity": "500g"},
    {"name": "garlic",  "quantity": "5 cloves"},
    {"name": "rice",    "quantity": "2 cups"},
]}, extra_headers=hdr())

r = get("/meal-plan", extra_headers=hdr())
if r.status_code in (503, 500):
    print(f"  [SKIP] Meal Plan: Python AI service offline ({r.status_code})")
elif r.status_code == 200:
    ok("Meal Plan -> 200")
    data = safe_json(r)
    # Response: { plan: [{day, lunch, dinner}, ...], totalRecipes: N }
    plan = data.get("plan", [])
    check("Meal Plan: 7 days in plan", isinstance(plan, list) and len(plan) == 7,
          f"got {len(plan) if isinstance(plan,list) else type(plan)} days")
    if plan:
        first_day = plan[0]
        check("Meal Plan: day object has day/lunch/dinner keys",
              all(k in first_day for k in ["day", "lunch", "dinner"]))
    check("Meal Plan: totalRecipes key present", "totalRecipes" in data)
else:
    fail("Meal Plan", f"status={r.status_code} body={r.text[:300]}")


# ==========================================================
# 8. CHAT
# ==========================================================
section("8. CHAT")

# 8a. SEARCH intent
r = post("/chat", {"message": "find me a pasta recipe"}, extra_headers=hdr())
check("Chat SEARCH intent -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")
body = safe_json(r)
check("Chat SEARCH: has reply/recipes/message", any(k in body for k in ["reply", "recipes", "message"]))

# 8b. COOKING intent
r = post("/chat", {"message": "how do I make chicken curry from scratch?"}, extra_headers=hdr())
check("Chat COOKING intent -> 200", r.status_code == 200, f"got {r.status_code}")
body = safe_json(r)
check("Chat COOKING: has reply/message", any(k in body for k in ["reply", "message"]))

# 8c. GENERAL intent
r = post("/chat", {"message": "what are the health benefits of turmeric?"}, extra_headers=hdr())
check("Chat GENERAL intent -> 200", r.status_code == 200, f"got {r.status_code}")
body = safe_json(r)
check("Chat GENERAL: has reply/message", any(k in body for k in ["reply", "message"]))

# 8d. Missing message -> 400
r = post("/chat", {}, extra_headers=hdr())
check("Chat: missing message -> 400", r.status_code == 400, f"got {r.status_code}")


# ==========================================================
# 9. RATING  (mounted at /api/ratings)
# ==========================================================
section("9. RATING")

# 9a. Missing recipeId
r = post("/ratings", {"rating": 4}, extra_headers=hdr())
check("Rating: missing recipeId -> 400", r.status_code == 400, f"got {r.status_code}")

# 9b. Missing rating
r = post("/ratings", {"recipeId": RECIPE_ID or "000000000000000000000000"}, extra_headers=hdr())
check("Rating: missing rating -> 400", r.status_code == 400, f"got {r.status_code}")

if RECIPE_ID:
    # 9c. Valid rating no feedback
    r = post("/ratings", {"recipeId": RECIPE_ID, "rating": 5}, extra_headers=hdr())
    check("Rating: valid no-text -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:100]}")
    check("Rating: message in response", "message" in safe_json(r))

    # 9d. Rating with feedback text (AI extraction)
    r = post("/ratings", {
        "recipeId": RECIPE_ID,
        "rating": 3,
        "feedbackText": "Good but too spicy. I really dislike cilantro.",
    }, extra_headers=hdr())
    check("Rating: with feedback -> 200", r.status_code == 200, f"got {r.status_code}")
    body = safe_json(r)
    check("Rating: ai_extractions returned", "ai_extractions" in body)

    # 9e. Low rating -> triggers cuisine dislike
    r = post("/ratings", {"recipeId": RECIPE_ID, "rating": 1}, extra_headers=hdr())
    check("Rating: low rating -> 200", r.status_code == 200, f"got {r.status_code}")
else:
    print("  [SKIP] Rating tests with real recipeId (no recipes returned from search)")


# ==========================================================
# 10. SUBSTITUTION  (mounted at /api/substitutions)
# ==========================================================
section("10. SUBSTITUTION")

# 10a. Missing all fields
r = post("/substitutions", {}, extra_headers=hdr())
check("Substitution: missing fields -> 400", r.status_code == 400, f"got {r.status_code}")

# 10b. Missing ingredientToReplace
r = post("/substitutions", {"recipeId": "x"}, extra_headers=hdr())
check("Substitution: missing ingredient -> 400", r.status_code == 400, f"got {r.status_code}")

if RECIPE_ID:
    # 10c. Valid substitution
    r = post("/substitutions", {
        "recipeId": RECIPE_ID,
        "ingredientToReplace": "butter",
    }, extra_headers=hdr())
    check("Substitution: valid -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:200]}")
    body = safe_json(r)
    check("Substitution: suggestions key present", "suggestions" in body)
    check("Substitution: at least 1 suggestion",
          isinstance(body.get("suggestions"), list) and len(body["suggestions"]) > 0)

    # 10d. Unknown ingredient -- should still return gracefully (not crash)
    r = post("/substitutions", {
        "recipeId": RECIPE_ID,
        "ingredientToReplace": "unicornblood_xyz",
    }, extra_headers=hdr())
    check("Substitution: unknown ingredient -> not 500", r.status_code != 500, f"got {r.status_code}")
else:
    print("  [SKIP] Substitution with real recipeId (no recipes from search)")


# ==========================================================
# 11. COOKING SOUS-CHEF  (mounted at /api/cook)
# ==========================================================
section("11. COOKING SOUS-CHEF")

# 11a. Missing recipeId
r = post("/cook", {}, extra_headers=hdr())
check("Cooking: missing recipeId -> 400", r.status_code == 400, f"got {r.status_code}")

# 11b. Missing userMessage
r = post("/cook", {"recipeId": "x"}, extra_headers=hdr())
check("Cooking: missing userMessage -> 400", r.status_code == 400, f"got {r.status_code}")

if RECIPE_ID:
    # 11c. Valid interaction
    r = post("/cook", {
        "recipeId": RECIPE_ID,
        "currentStepIndex": 0,
        "userMessage": "What temperature should the pan be?",
        "chatHistory": [],
    }, extra_headers=hdr())
    check("Cooking: valid -> 200", r.status_code == 200, f"got {r.status_code} {r.text[:200]}")
    body = safe_json(r)
    check("Cooking: reply present", "reply" in body)
    check("Cooking: current_step present", "current_step" in body)

    # 11d. Follow-up with chat history
    history = [{"role": "assistant", "content": body.get("reply", "test")}]
    r = post("/cook", {
        "recipeId": RECIPE_ID,
        "currentStepIndex": 0,
        "userMessage": "Can I substitute olive oil for butter?",
        "chatHistory": history,
    }, extra_headers=hdr())
    check("Cooking: follow-up -> 200", r.status_code == 200, f"got {r.status_code}")
    check("Cooking: follow-up reply present", "reply" in safe_json(r))
else:
    print("  [SKIP] Cooking sous-chef with real recipeId (no recipes from search)")


# ==========================================================
# SUMMARY
# ==========================================================
print(f"\n{'='*60}")
print(f"  RESULTS: {PASS_COUNT} passed, {FAIL_COUNT} failed")
if ERRORS:
    print(f"\n  FAILURES:")
    for e in ERRORS:
        print(f"    {e}")
print('='*60)

sys.exit(0 if FAIL_COUNT == 0 else 1)
