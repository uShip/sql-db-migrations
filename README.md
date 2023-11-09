# SQL Database Migrations

This repo orchestrates database schema migrations across multiple environments—Dev, QA, Prod, and Sandbox—using Flyway. Instead of versioned migrations, we use repeatable migrations.

## Adding Migrations

### Create a Branch
To begin working on a new migration, create a branch in the repository using the following naming convention: `{environment}/deployment/{short-description}`

**Example:**
`dev/deployment/add-new-tables`


### Add SQL Script
For each migration, add your repeatable SQL script to the `sql/` directory. Use the naming conventions below:

- **Table**: `R__{TableName}.sql`
  - Example: `R__Users.sql`
- **Stored Procedure**: `R__SP_{SprocName}.sql`
  - Example: `R__SP_GetPrices.sql`
- **View**: `R__VW_{ViewName}.sql`
  - Example: `R__VW_UserProfiles.sql`

## Workflow

1. **Implement Changes**: Make your changes in the feature branch and commit them.
2. **Open a PR**: Start the CI/CD pipeline by triggering the "Actions".
3. **Await DBA Approval**: The changes will be reviewed by a DBA team member. Upon approval, the workflow will handle the deployment.
4. **Merge Changes**: After deployment and final verification, open pr to merge into the `main` branch.

## Rollbacks

To revert changes, deploy from a branch containing the previous version of the script. This overrides the current script in the environment with the version from that branch.
