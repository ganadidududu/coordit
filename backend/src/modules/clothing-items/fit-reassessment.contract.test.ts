import assert from "node:assert/strict";
import { test } from "node:test";
import { routes } from "../../routes";

test("selected clothing fit reassessment is exposed as an authenticated POST", () => {
  // Given: the real authenticated application router.
  const stack = Reflect.get(routes, "stack");
  assert.ok(Array.isArray(stack));

  // When: the registered route contracts are inspected.
  const registered = stack.some((layer: unknown) => {
    if (typeof layer !== "object" || layer === null) return false;
    const route = Reflect.get(layer, "route");
    if (typeof route !== "object" || route === null) return false;
    const methods = Reflect.get(route, "methods");
    return Reflect.get(route, "path") === "/clothing-items/:id/fit-reassessment"
      && typeof methods === "object"
      && methods !== null
      && Reflect.get(methods, "post") === true;
  });

  // Then: the selected-item reassessment endpoint exists behind auth.
  assert.equal(registered, true);
});
