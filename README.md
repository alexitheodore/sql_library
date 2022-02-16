## git

To clone library without using submodules or subtrees:

```
cd ../cmt_db
rm -R sql_library
git clone --separate-git-dir ../sql_library_git https://github.com/alexitheodore/sql_library.git
```

Then make sure that the parent repo has `sql_library/.git*` in its `.gitignore` file.

This will make the `sql_library` a new repo under independent control without the parent repo having any knowledge of it.


