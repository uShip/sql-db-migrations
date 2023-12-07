# db-infra

1. install pre-commit
2. Add a pre-commit configuration
3. Install the git hook scripts
    pre-commit install
4. Run against the files
    pre-commit run --all-files



### DataOps Pipeline README

This repository outlines the DataOps pipeline for managing SQL changes and deployments.

#### Branch Creation:

* Create a new branch with the following format: ```JIRA_ticket_number-brief_descriptive_title```. Example: ```SQL-1043-update-column```.
* Make your changes to the relevant SQL files.

#### SQL File Location:

* Place your SQL files within the appropriate schema folder under the sql directory.
* A specific pricing folder already exists for all pricing-related files.
* The pricing folder is further divided into subfolders:
    * non-repeatable: Stores table creation and one-time data insertion scripts.
    * repeatable: Stores views and SPROCs.

#### Pull Request Creation:

* Once your changes are complete, create a pull request (PR) from your branch to the main branch.
* Utilize the provided PR template to clearly explain your changes and their purpose.
* Request a review from the data team.
* Notify the data team on the dedicated channel to ensure review and approval.

#### PR Approval and Merge:

* After successful review and approval from the data team, merge your PR into the main branch.

#### Deployment Workflow:

* An alert will be sent to the data team upon PR merge into the main branch.
* The data team must then approve the deployment within GitHub Actions.
* Once approved, the changes will be deployed and reflected in the environment.

#### Additional Notes:

* Please adhere to the defined folder structure to ensure organization and clarity.
* Utilize the provided PR template for consistent and informative updates.
* Communicate effectively with the data team through pull requests and channel notifications.
* Remember to follow the established guidelines for code style and best practices.
* Feel free to contact the ```data team``` if you have any questions or require further assistance!
