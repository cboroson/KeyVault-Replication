
# Key Vault Replication

Replicates Key Vault secrets between Azure Key Vaults in the same subscription.

## Getting Started

Azure does not yet offer a way to replicate Key Vault secrets between Key Vaults.  Although Azure guarantees a certain level of availability for Key Vault resources, and they offer replication of Key Vaults between paired regions, these protections are insufficient for the following reasons:

- Azure will only recover Key Vault resources as part of the recovery of an entire region.  For most customers, individual Key Vault resources cannot be recovered if they are deleted or corrupted.
- Key Vaults recovered by Azure as part of a disaster recovery effort are not writable.  Key Vault actions are limited to read operations.
- Azure's Key Vault replication cannot recover individual secrets
- Data protection (backup and restore operations) are not possible with Azure's Key Vault replication 

This extension attempts to address these limitations for Key Vault secrets.  Secrets can be replicated between two Key Vaults in the same Azure subscription.

This extension allows for one-way or two-way replication of secrets.  One-way replication can be used to mirror a source Key Vault to a target Key Vault, with the option of deleting extraneous secrets in the target.  Two-way replication offers two Key Vaults to be used in tandem, with new secrets and new secret versions being copied in both directions.  There are two things to note regarding two-way replication:

- Two-way replication disables target secret deletion since the extension cannot determine what is extraneous and what was intentionally added by administrators.
- Since two-way replication cannot replicate deletions, administrators must be cautious when deleting Key Vault secrets.  If the same secret is not deleted on both Key Vaults involved in the replication, the next replication run will recreate the deleted secret on the target Key Vault.  Therefore, administrators are advised to delete secrets on both Key Vaults involved in the replication.

### Limitations with VSTS's native Key Vault integration
This extension does not currently replicate Certificates or Keys.  It also does not replicate Key Vault access policies.  Also, this extesion cannot replicate across Azure subscriptions due to limitations inherent to the encryption of Key Vault backup files.

### Prerequisites
This extension requires two existing Key Vaults in an accessible Azure subscription.  These Key Vault resouces must also be accessible from the VSTS service principal that executes the pipeline.

## Configuration
*Ensure that the VSTS service principal has sufficient permissions to the source and target Key Vaults*


## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

* Craig Boroson 

See also the list of [contributors](https://github.com/cboroson/KeyVault-Replication/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details


