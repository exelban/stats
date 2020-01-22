# How to contribute

Bug-fixes and features often come from users of the Charts framework, and improving it greatly. We want to keep it as easy as possible to contribute changes that improve the experience for users all around the world. There are a few guidelines that we
need contributors to follow so that we can have a chance of keeping on
top of things.

## Simple issues and bug reports

If you are reporting a bug which can be observed visually, please add to your issue either:

* Screenshots, if the bug is easily explainable
* A working sample project that we can compile, run, and immediately observe the issue

## Getting Started with Contributions

* Make sure you have a [GitHub account](https://github.com/signup/free)
* Submit a ticket for your issue, assuming one does not already exist.
  * Clearly describe the issue including steps to reproduce when it is a bug.
  * Make sure you fill in the earliest version (or commit number) that you know has the issue.
* Fork the repository on GitHub

## Making Changes

* Create a topic branch from where you want to base your work. This is usually the master branch.
* Make commits of logical units.
* Make sure your code conforms to the code style around it. It's easy, just look around!
* If you have made changes back and forth, or have made merges, your commit history might look messy and hard to understand. A single issue or change should still be in one commit. So please squash those commits together and rebase them however you need to - to make our lives easier when reading it later.
* Check for unnecessary whitespace with `git diff --check` before committing.
* Make sure your commit messages are in the proper format.

````
    First line must be up to 50 chars (Fixes #1234)

    The first line should be a short statement as to what have changed, and should also include an issue number, prefixed with a hash.
    The body of the message comes after an empty new line, and describes the changes
    more thoroughly, especially if there was a special case handled there,
    or maybe some trickery that only code wizards can understand.
````

* Make sure you have tested your changes well.
* If your changes could theoretically affect some other component or case, which you do not necessarily use, you still have to test it.
* Create a Pull Request from your topic branch to the relevant branch in the main repo. If you go to the main repo of the framework, you'll see a big green button which pretty much prepares the PR for you. You just have to hit it.

## Making Trivial Changes

For changes of a trivial nature to comments and documentation, it is not
always necessary to create a new ticket. In this case, it is
appropriate to start the first line of a commit with '(doc)' instead of
a ticket number. Even the default commit message the GitHub generates is fine with us.
