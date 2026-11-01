# Quizzer product

## Purpose

Quizzer is a generic offline quiz-practice application built with Go
and Fyne.

Users import question banks, create reusable quiz definitions, and
practice them. Each playthrough is a separate session constructed
from the quiz's configuration.

## Startup and navigation

The application starts with an empty quiz list.

A + button opens a dropdown menu with an Add quiz action.
The menu can accommodate additional actions later.

Adding a quiz opens a configuration flow:

1. Load a JSON question bank or select an already imported bank.
2. Enter a quiz name.
3. Select one or more topics.
4. Choose ordered or shuffle mode.
5. Set the maximum number of questions per topic.
6. Confirm creation.

The new quiz appears in the list with a Play action.
Adding a quiz does not start a session.

Canceling creation must not add a partial quiz to the list.

## Question banks

A bank contains topics in source order.
Each topic contains questions in source order.

A question contains:

- A prompt.
- Ordered answer options.
- Exactly one correct answer.
- An optional explanation.

Question banks are external JSON files, not embedded application content.
The JSON contract is defined in question-format.md.

Validate the complete bank before making it available.
A failed import must not modify existing banks, quizzes, or sessions.
Importing another bank must not silently replace an existing bank.

## Quiz definitions

A quiz definition contains:

- A display name.
- Its question bank.
- Selected topics.
- Ordered or shuffle mode.
- A positive maximum question count per topic.

Definitions are reusable during the current application run.
They contain configuration, not submitted answers or a precomputed
question sequence.

## Starting a session

Pressing Play constructs a fresh session from the quiz definition.

For each selected topic, in bank source order:

- Ordered mode takes questions in source order.
- Shuffle mode shuffles questions before applying the per-topic limit.
- Include up to the configured number of questions.
- If fewer questions are available, include all of them.

Questions remain grouped by topic; do not interleave topics.
Select questions without replacement within each topic.
Do not shuffle answer options.

The resulting sequence is fixed for the duration of the session.

Repeated shuffled sessions may differ in selected questions, order, or
both. Random sessions may also repeat; differences are not guaranteed.

## Practice

- Display one question at a time.
- Require an answer selection before submission.
- Accept one submission per question.
- After submission, show correctness, the correct answer, and any explanation.
- Allow progression to the next question.
- On completion, show correct answers out of total questions.
- Allow returning to the quiz list.

Playing the quiz again creates a new session with no previous answers.

## MVP data lifetime

Imported banks, quiz definitions, and sessions remain in memory.
Closing the application discards them.
Imported JSON files are not modified.

## Later milestone

Introduce local database persistence and in-app question management,
including adding and removing questions.

Keep question banks, quiz definitions, and session history distinct.
Define how question updates affect existing quizzes and historical
results when implementing persistence.
