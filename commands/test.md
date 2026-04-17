You are a senior QA engineer tasked with writing and running end-to-end tests for a fully built app using Playwright. This command runs after `/build` — the app must already be built and the dev server must be running before you start.

## Before Starting

1. Read `CLAUDE.md` — understand the app structure, stack, and feature inventory.
2. Read `PRD.md` — the acceptance criteria here define what must be tested.
3. Confirm the dev server is running. If it is not, tell the user to start it first (`npm run dev`) and re-run `/test`.

## What to Test

Write E2E tests for every user flow listed in PRD.md. Cover:

### 1. Core User Flows
- For each feature marked as `built` in CLAUDE.md, write a test that walks through the full user journey from the browser.
- Follow the acceptance criteria in PRD.md as the definition of pass/fail.

### 2. Navigation
- Test that all screens are reachable and render without errors.
- Test navigation links, back buttons, and redirects.

### 3. Forms & Inputs
- Test form submissions with valid data — expect success.
- Test form submissions with invalid data — expect proper error messages.
- Test empty states — what does the user see when there is no data?

### 4. Authentication (if applicable)
- Test login with valid credentials.
- Test login with invalid credentials.
- Test that protected routes redirect unauthenticated users.
- Test logout.

### 5. Error States
- Test what happens when an API call fails.
- Test 404 pages and unexpected routes.

## Test Structure

- Place all tests in a `e2e/` folder at the project root.
- One file per feature: `e2e/[feature-name].spec.ts`
- Use descriptive test names that match the user story: `test('user can submit a new expense', ...)`
- Use Playwright's `page` fixture — no custom abstractions unless there is clear repetition.

## Running Tests

After writing all tests:
1. Run the full test suite: `npx playwright test`
2. If a test fails:
   - Investigate whether it is a test issue or a real bug
   - If it is a real bug, fix the code and re-run
   - If it is a test issue, fix the test
3. All tests must pass before reporting completion.

## When Tests are Complete

1. Update `CLAUDE.md`:
   - Add a `## Test Coverage` section listing which flows are covered by E2E tests.

2. Report to the user:
   - How many tests were written and how many passed
   - Any bugs found and fixed during testing
   - Any flows that could not be tested and why
   - Confirmation that the app is ready to ship
