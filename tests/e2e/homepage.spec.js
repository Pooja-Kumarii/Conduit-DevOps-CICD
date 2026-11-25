const { test, expect } = require("@playwright/test");

test("Homepage loads successfully", async ({ page }) => {
  const response = await page.goto("/");

  expect(response.status()).toBe(200);
  await expect(page).toHaveTitle(/Conduit/i);
});

test("Sign up option is visible", async ({ page }) => {
  await page.goto("/");

  await expect(
    page.getByRole("link", { name: "Sign up", exact: true })
  ).toBeVisible();
});

test("Articles API returns successfully", async ({ request }) => {
  const response = await request.get("/api/articles");

  expect(response.status()).toBe(200);

  const data = await response.json();

  expect(Array.isArray(data.articles)).toBe(true);
});