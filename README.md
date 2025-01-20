# The Acess key for the Keypair:

To fix this, you'll need to restrict the file permissions of `new1.pem` so that it's only readable by the owner. Here’s how you can do it:

1. **Change the permissions of your private key**:

   Open a terminal and run the following command to restrict the permissions to `600` (read and write permissions for the owner only):

   ```bash
   chmod 600 new1.pem

   or 

   chmod 400 new1.pem
   ```

2. **Verify the permissions**:

   You can verify that the permissions have been set correctly by running:

   ```bash
   ls -l new1.pem
   ```

   The output should look something like this:

   ```bash
   -rw------- 1 user user 1692 Jan 15 12:34 new1.pem
   ```

   The important part is that the file permissions are `-rw-------`, which means only the owner can read and write the file.

3. **Try connecting again**:

   Now, try to connect to your EC2 instance again using the same SSH command:

   ```bash
   ssh -i new1.pem ec2-user@34.220.144.49
   ```

   This should resolve the "bad permissions" error.

### Additional Notes:
- If the file is still not being accepted, make sure the private key is correctly associated with the EC2 instance you're trying to connect to.
- If you're using a different user (other than `ec2-user`), make sure to replace `ec2-user` with the appropriate username for your instance.

Let me know if that works or if you run into any other issues!


# Free Tier Tricks

To ensure that the resources are eligible for the AWS Free Tier, we need to make sure that we are using the appropriate instance types, storage classes, and other configurations that fall within the Free Tier limits. Here are the adjustments:

EC2 Instance: Use t2.micro or t3.micro instance types.
RDS Instance: Use db.t2.micro or db.t3.micro instance types.
S3 Bucket: Use the Standard storage class, which is eligible for the Free Tier.
Redshift Cluster: Use dc2.large node type, which is eligible for the Free Tier for 2 months.
EMR Cluster: Use m5.large or m4.large instance types, which are eligible for the Free Tier for 50 hours per month.
