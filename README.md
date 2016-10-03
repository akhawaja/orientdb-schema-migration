# OrientDB Schema Migration #

## Introduction ##

This project contains bash scripts to apply schema migrations to an OrientDB database. There are two key scripts. The script named _odb-migrations-pre-2_2.sh_ is designed to work with OrientDB versions prior to 2.2.x. The other script named _odb-migrations.sh_ is designed to work with OrientDB versions from 2.2.x onwards. These shell scripts are standalone.

## Quick Start ##

Let's presume that you are using OrientDB 2.2.x. Let's also presume that you have placed the script _odb-migrations.sh_ in the root of your project. Ideally, you should put that script somewhere in your shell path. To begin, let's create a new script.

```bash
$> ./odb-migrations.sh -c "my first schema migration" -d "migrations"
```

This will create a script named similar to _20161003231716_my_first_schema_migration.osql_. Open this file and start writing OrientDB valid SQL. Let's write the following:

```sql
CREATE VERTEX Product EXTENDS V;
CREATE PROPERTY Product.name string;
CREATE PROPERTY Product.price double;

CREATE INDEX Product.name UNIQUE;
```

Now, we can run this migration.

```bash
$> ./odb-migrations.sh -m "*" -d "migrations" -u myusername -p mypassword -h localhost -n "my-db-name"
```

Let's breakdown what the shell script will do:

1. It will match (-m) all the files in the directory (-d) named _migrations_.
1. It will connect to your OrientDB server to the database (-n) named _my-db-name_ with the username (-u) _myusername_ and password (-p) _mypassword_.
1. It will check to see if there is a Vertex named _Migration_ and if not, it will create it. This is where all the schema migrations that have already been applied will be stored.
1. Read the migration script and apply the SQL to the database.

As it goes through each file, it will tell you which ones have been successfully applied.

### Stored Functions in Migrations ###

You can include [Stored Functions](http://orientdb.com/docs/2.2/Functions.html) in your schema migrations as well. The way you add those in is by escaping the JavaScript and adding the necessary SQL around it so OrientDB can store this information. Here is a sample:

```sql
-- Delete the function first if it exists
DELETE FROM OFunction WHERE name = 'multiplyNumbers';

-- Create the function
CREATE FUNCTION multiplyNumbers "/**\n * Multiply two numbers\n * @param {int} num1 - First number\n * @param {int} num2 - Second number\n * @return {int} Product of two numbers.\n */\nreturn num1 * num2;" PARAMETERS [num1, num2] LANGUAGE javascript ;
```

Here is the function unescaped:

```javascript
/**
 * Multiply two numbers
 * @param {int} num1 - First number
 * @param {int} num2 - Second number
 * @return {int} Product of two numbers.
 */
return num1 * num2;
```

That is it! Since it is a self-contained shell script, you can make it part of your build process however you like.

## Schema Migration Accumulation ##

Over time, you will find that your migrations directory will become cluttered with more and more scripts. The shell script supplied in this project does not keep track of which files were alread run outside of the OrientDB database. As a practice, you can move the scripts already applied to a different folder, let's just call it _migrations-archive_ and keep your _migrations_ folder trim.