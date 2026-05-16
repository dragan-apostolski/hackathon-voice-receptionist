# Repository Instructions

- Treat `.plain` files, templates, resources, config, and test scripts as the source of truth.
- Do not manually patch generated code in `plain_modules/`, `dist/`, `conformance_tests/`, or `dist_conformance_tests/`.
- If generated behavior is wrong, diagnose it from the generated output, then fix the corresponding `.plain` spec, template, resource, config, or test script and re-render with codeplain.
- Generated folders are disposable renderer artifacts and should stay untracked.
