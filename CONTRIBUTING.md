# Contributing

Thanks for taking the time. One person maintains this, so the process is short.

## Reporting a problem

Open an issue. What helps:

- what you did in the panel and what happened instead;
- the plugin version, the Notepad++ version, and whether it is the x64 build;
- for a drawing problem, a screenshot; for a wrong number, the formula.

If the panel does not open at all, the plugin writes a log to your temporary
folder - graphbuilder.log for the Delphi build, graphbuilderlaz.log for the
Lazarus one. The last lines of it usually name the cause.

## Sending a change

Building both halves is described in the README, including which one needs the
whole library and which needs a single file.

- keep one change about one thing;
- the panel is a web page and the computing is Object Pascal; a change that
  touches both has to keep them in step, and the page carries a version that the
  library checks on startup;
- run the tests in tests/ and put in the pull request what you ran and what it
  printed.

## Terms

By opening a pull request you agree that your contribution is licensed to
the project owner under the MIT licence, and that the owner may relicense
the project, including your contribution, under different terms in the
future.

You keep the copyright to what you wrote. This is a licence grant, not a
transfer: it exists so the project can change its licence later without
tracking down everyone who ever sent a patch.
