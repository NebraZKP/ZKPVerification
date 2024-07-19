# ZKP Verification Cost Dashboard Repo

🗝️ Welcome to the **ZKP (zero-knowledge proof) Verification Cost** dashboard repository! This dashboard is a collaborative effort aimed at understanding the trends and developments in zero-knowledge proof verification costs. We analyze the verification costs of various projects, whether they are infrastructure like roll-ups or dApps, focusing on gas costs and the number of transactions involved. Currently, our analysis is limited to activities on the Ethereum L1 chain, but we plan to extend to other ecosystems such as Base, Optimism, and Polygon in the near future.

🙋 We welcome community contributions! If you spot a gap, inaccuracy, want to add a missing project, or propose a methodology change, please follow the guide below.

_ℹ️ To learn more about how queries in this dashboard are managed, please [visit this doc](https://dune.mintlify.app/api-reference/queries/endpoint/query-object)._

## ⚒️ How to Contribute 

### I want to make changes to existing projects 🧹

1. **Audit and Modify Visuals**: 
   - Click into any visual on the chart and audit the logic powering the visual. The entry point is likely an aggregation of all projects unioned together. Follow the commented links to the raw logic of the project.
   - Example: Click into [this visual](https://dune.com/queries/3902528/6589186) and follow the link to the [base query for Scroll](https://dune.com/queries/3916549). Examine and modify the logic as needed.

2. **Test Changes**: 
   - Test your changes in your own query on Dune.com. Ensure your modified SQL works as expected.

3. **Propose Changes**: 
   - Find the corresponding query file under `/queries` folder (it will end in the same query ID, e.g., `3916549` for Scroll). Replace the SQL logic with your proposed changes but keep the top comment part intact.
   - Raise a PR with the title beginning with **🏷️ "Project logic improvement for..."**.

### I want to add a new project 🌱

1. **Write a Query**: 
   - Write a query for the new project with the desired SQL logic. The output should include daily verification costs and the number of verifying transactions.
   - Expected schema: `block_date`, `verifying_calls`, `verifying_cost_ETH`, `verifying_cost_usd`. Refer to this [Linea verification base query](https://dune.com/queries/3916566?sidebar=none) for inspiration.

2. **Propose New Project**: 
   - Raise a PR with links to the base verification queries for the new project. Include project documentation links and specify whether the project is infrastructure or an app. 
   - Title the PR beginning with **🏷️ "Add project..."**.

### I want to add new analysis (visualizations from new queries) 🎨

1. **Propose New Analysis**: 
   - Raise a PR with the title beginning with **🏷️ "Add new chart..."**. Include the proposed query link and the visualization link (e.g., https://dune.com/queries/3902528/6589186).
   - Provide extra context on what you are suggesting.

---
## 👷‍♂️ How to Manage the Repo

### Setup Your Repo

1. Generate an API key from your Dune account and put that in both your `.env` file and [github action secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository) (name it `DUNE_API_KEY`). You can create a key under your Dune team settings. *The api key must be from a plus plan for this repo to work.*

2. Type your intended query ids into the `queries.yml` file. The id can be found from the link `https://dune.com/queries/<query_id>/...`. If you're creating this for a dashboard, go to the dashboard you want to create a repo and click on the "github" button in the top right of your dashboard to see the query ids.

3. Then, run `pull_from_dune.py` to bring in all queries into `/query_{id}.sql` files within the `/queries` folder. Directions to setup and run this python script are below.

### Query Management Scripts

You'll need python and pip installed to run the script commands. If you don't have a package manager set up, then use either [conda](https://www.anaconda.com/download) or [poetry](https://python-poetry.org/) . Then install the required packages:

```
pip install -r requirements.txt
```

| Script | Action                                                                                                                                                    | Command |
|---|-----------------------------------------------------------------------------------------------------------------------------------------------------------|---|
| `pull_from_dune.py` | updates/adds queries to your repo based on ids in `queries.yml`                                                                                           | `python scripts/pull_from_dune.py` |
| `push_to_dune.py` | updates queries to Dune based on files in your `/queries` folder                                                                                          | `python scripts/push_to_dune.py` |
| `preview_query.py` | gives you the first 20 rows of results by running a query from your `/queries` folder. Specify the id. This uses Dune API credits | `python scripts/preview_query.py 2615782` |

---

### Things to be aware of

💡: Names of queries are pulled into the file name the first time `pull_from_dune.py` is run. Changing the file name in app or in folder will not affect each other (they aren't synced). **Make sure you leave the `___id.sql` at the end of the file, otherwise the scripts will break!**

🟧: Make sure to leave in the comment `-- already part of a query repo` at the top of your file. This will hopefully help prevent others from using it in more than one repo.

🔒: Queries must be owned by the team the API key was created under - otherwise you won't be able to update them from the repo.

➕: If you want to add a query, add it in Dune app first then pull the query id (from URL `dune.com/queries/{id}/other_stuff`) into `queries.yml`

🛑: If you accidently merge a PR or push a commit that messes up your query in Dune, you can roll back any changes using [query version history](https://dune.com/docs/app/query-editor/version-history).

---