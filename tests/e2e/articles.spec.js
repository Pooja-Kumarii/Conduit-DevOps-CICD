const { test, expect } = require("@playwright/test");
const { randomUUID } = require("node:crypto");

test.beforeEach(async ({ page }) => {
  const id = randomUUID().slice(0, 12);

  await page.goto("/");

  await page.getByRole("link", {
    name: "Sign up",
    exact: true,
  }).click();

  await page.getByPlaceholder("Your Name").fill(`user_${id}`);
  await page.getByPlaceholder("Email").fill(`${id}@example.com`);
  await page.getByPlaceholder("Password").fill("DevOpsTest123!");

  await page.getByRole("button", {
    name: "Sign up",
    exact: true,
  }).click();

  await expect(
    page.getByRole("link", { name: "New Article" })
  ).toBeVisible();
});

async function createArticle(page) {
  const title = `DevOps Article ${randomUUID().slice(0, 8)}`;

  await page.getByRole("link", {
    name: "New Article",
  }).click();

  await page.getByPlaceholder("Article Title").fill(title);

  await page.getByPlaceholder(
    "What's this article about?"
  ).fill("Automated CI/CD testing");

  await page.getByPlaceholder(
    "Write your article (in markdown)"
  ).fill("This article was created using Playwright automation.");

  await page.getByPlaceholder("Enter tags").fill("DevOps,Jenkins");

  await page.getByRole("button", {
    name: "Publish Article",
  }).click();

  await expect(
    page.getByRole("heading", { name: title, exact: true })
  ).toBeVisible();

  return title;
}

test("User can publish an article", async ({ page }) => {
  await createArticle(page);
});

test("User can edit an article", async ({ page }) => {
  const title = await createArticle(page);
  const updatedTitle = `${title} Updated`;

  await page.getByRole("link", {
    name: "Edit Article",
  }).first().click();

  await page.getByPlaceholder("Article Title").fill(updatedTitle);

  await page.getByRole("button", {
    name: "Update Article",
  }).click();

  await expect(
    page.getByRole("heading", {
      name: updatedTitle,
      exact: true,
    })
  ).toBeVisible();
});

test("User can post a comment", async ({ page }) => {
  await createArticle(page);

  const comment = "This is an automated Playwright comment.";

  await page.getByPlaceholder("Write a comment...").fill(comment);

  await page.getByRole("button", {
    name: "Post Comment",
  }).click();

  await expect(
    page.getByText(comment, { exact: true })
  ).toBeVisible();
});

test("User can delete an article", async ({ page, request }) => {
  await createArticle(page);

  const slug = page.url().split("/article/")[1];

  expect(slug).toBeTruthy();

  page.once("dialog", (dialog) => dialog.accept());

  await page.getByRole("button", {
    name: "Delete Article",
  }).first().click();

  await expect(page).toHaveURL(/\/#\/?$/);

  const response = await request.get(`/api/articles/${slug}`);

  expect(response.status()).toBe(404);
});