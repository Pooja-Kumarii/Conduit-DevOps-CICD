const { test, expect } = require("@playwright/test");
const { randomUUID } = require("node:crypto");

const password = "DevOpsTest123!";

function newUser() {
  const id = randomUUID().slice(0, 12);

  return {
    username: `devops_${id}`,
    email: `devops_${id}@example.com`,
    password,
  };
}

test("New user registration", async ({ page }) => {
  const user = newUser();

  await page.goto("/");

  await page.getByRole("link", {
    name: "Sign up",
    exact: true,
  }).click();

  await page.getByPlaceholder("Your Name").fill(user.username);
  await page.getByPlaceholder("Email").fill(user.email);
  await page.getByPlaceholder("Password").fill(user.password);

  await page.getByRole("button", {
    name: "Sign up",
    exact: true,
  }).click();

  await expect(
    page.getByRole("link", { name: "New Article" })
  ).toBeVisible();
});

test("Valid user login", async ({ page, request }) => {
  const user = newUser();

  const registration = await request.post("/api/users", {
    data: { user },
  });

  expect(registration.ok()).toBeTruthy();

  await page.goto("/");

  await page.getByRole("link", {
    name: "Login",
    exact: true,
  }).click();

  await page.getByPlaceholder("Email").fill(user.email);
  await page.getByPlaceholder("Password").fill(user.password);

  await page.getByRole("button", {
    name: "Login",
    exact: true,
  }).click();

  await expect(
    page.getByRole("link", { name: "New Article" })
  ).toBeVisible();
});

test("Invalid login is rejected", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("link", {
    name: "Login",
    exact: true,
  }).click();

  await page.getByPlaceholder("Email").fill(
    `${randomUUID()}@example.com`
  );

  await page.getByPlaceholder("Password").fill("WrongPassword123");

  const responsePromise = page.waitForResponse(
    (response) =>
      response.url().includes("/api/users/login") &&
      response.request().method() === "POST"
  );

  await page.getByRole("button", {
    name: "Login",
    exact: true,
  }).click();

  const response = await responsePromise;

  expect([400, 401, 403, 422]).toContain(response.status());

  await expect(
    page.getByRole("button", { name: "Login", exact: true })
  ).toBeVisible();
});