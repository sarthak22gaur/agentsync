# Durable References (Hard Rule)

Plans, phase labels, grill rounds, handoffs, ledgers, port logs, and anything else under `workspace/` are private working documents. They move, get renamed, and are never published, so a reference to one rots the moment it's written.

Never mention them in code, comments, docstrings, test names, fixtures, branch names, commit messages, or PR titles and bodies. That covers file paths, plan or phase identifiers, grill or finding numbers, and lane names. Explain the durable reason in plain domain terms, or leave it out. Public, stable references (an issue tracker ID, a published spec, an upstream bug URL) are fine where the project's conventions use them.
