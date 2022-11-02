##git

How to add this to a git repo as an externally managed "subrepo" (I think its the best way):

1. Create the desired location dir within the destination repo ("dir_sql_lib_dest")
 - this is where the code will live inside the destination project
 - do whatever you like to the code and it will me committed to the destination repo as if it was owned by it.
 - all management of the sql_library repo (commits/pulls/merges/etc.) will be done externally.

2. Create a root directory outside the destination repo ("dir_sql_lib_root")
 - this is where sql_library code will be reconciled back to the origin repo (if desired at all)

3. $`cd {dir_sql_lib_dest}` and $`git init --separate-git-dir {dir_sql_lib_root}`
 - this initializes the sql_library repo in the dest dir but with the git root outside

4. `git remote add origin git@alexitheodore.git:alexitheodore/sql_library.git`

5. Make sure that this (or something similar) is in ~/.ssh/config :

`
Host alexitheodore.git
        HostName github.com
        User alexitheodore
        PreferredAuthentications publickey
        IdentityFile /Volumes/Files/alexitheodore/.ssh/alexitheodore-GitHub
        UseKeychain yes
        AddKeysToAgent yes
`

