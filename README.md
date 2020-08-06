
# 🧿Elizium.Loopz

[![A B](https://img.shields.io/badge/branching-commonflow-informational?style=flat)](https://commonflow.org)
[![A B](https://img.shields.io/badge/merge-rebase-informational?style=flat)](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)
[![A B](https://img.shields.io/github/license/plastikfan/loopz)](https://github.com/plastikfan/Loopz/blob/master/LICENSE)
[![A B](https://img.shields.io/powershellgallery/p/Elizium.Loopz)](https://www.powershellgallery.com/packages/Elizium.Loopz)

PowerShell iteration type utilities.

## Introduction

When writing a suite of utilities/functions it can be difficult to develop them so that they behave in a consistent manner. Along with another dependent Powershell module [Elizium.Krayola](https://github.com/plastikfan/Krayola), Elizium.Loopz can be used to build PowerShell commands that are both more visually appealing and consistent particularly with regards to rendering repetitive content as a result of some kind of iteration process.

The module can be installed using the standard **install-module** command:

> PS> install-module -Name Elizium.Loopz

### Dependencies

Requires [Elizium.Krayola](https://github.com/plastikfan/Krayola) which will be installed automatically if not already present.

## General Concepts

### :o: PassThru hash-table object

A common theme present in the main commands is the use of a Hash-table object called $PassThru.
The scenarios in which the PassThru are as follows:

* Allows calling code to send additional parameters to a Loopz command outside of its regular signature.
* Allows invoked code to return information back to calling code.

Let's elaborate the above points...

:star: First point: Invoke-ForeachFsItem requires calling code to either specify a script-block or a function (collectively called the invokee). The invokee must have to conform to a signature accepting the following four common arguments:

* Underscore: the current pipeline item
* Index: an allocated numeric value indicating the sequence number in the pipeline
* PassThru: the hash-table containing additional named items, and other information gathered throughout processing
* Trigger: client controlled boolean flag that should be used to denote if update/write action was taken for a particular item in pipeline. (Relevant for state changing operations only).

When additional parameters need to be sent to the invokee, there is already a mechanism for
passing these (either with *BlockParams* or *FuncteeParams*), this approach is generally preferred.

However, there is another commonly occurring pattern which would require the use of PassThru. This pattern is the adapter pattern. If there is an existing function that needs to be integrated to be used with Invoke-ForeachFsItem, but does not match the required signature, an intermediate adapter can be implemented. Calling code can put in any additional parameters (required by the non-conformant function) into the PassThru, which are picked up by the adapter and forwarded on as required. Using the adapter this way is much preferred than using additional parameters (*BlockParams* or *FuncteeParams*), because there could be confusion as to whom these parameters are required for, the adapter or the target function/script-block. Using parameters in PassThru can be made to be much clearer because very meaning names can be used as hast-table keys; Eg, for internal Loopz command interaction (Invoke-MirrorDirectoryTree internally invokes Invoke-TraverseDirectory and uses keys like 'LOOPZ.MIRROR.INVOKEE', which means that, that value is only of importance to Invoke-TraverseDirectory, so any other function that sees this should ignore it).

:exclamation: Note, users should use a similar namespaced style keys, for their own use, to avoid any chance of name clashes and users should not use any keys beginning with 'LOOPZ.' as these are reserved for internal Loopz operation.

:warning: Warning don't nest Invoke-ForeachFsItem calls, using the same PassThru instance. That is to say do not use a function/script-block already known to call 'Invoke-ForeachFsItem' with its own Invoke-ForeachFsItem request using the same PassThru instance. If you need to achieve this, then a new and separate PassThru instance should be created. However, recursive functions are fine, as long as it makes sense that different iterations use the same PassThru.

:star: Second point:

The *Invoke-MirrorDirectoryTree* command illustrates this well. Invoke-MirrorDirectoryTree needs to be able to present the invokee with multiple (actually, just 2) DirectoryInfo objects for each source directory encountered, one for the source directory and another for the mirrored directory. Since *Invoke-ForeachFsItem* is the command that under-pins this functionality, Invoke-MirrorDirectoryTree needs to conform to it's requirements, one of which is that a single DirectoryInfo is presented to the invokee. To get around this, it populates a new entry inside the PassThru: 'LOOPZ.MIRROR.ROOT-DESTINATION', which the invokee can now access. This same technique can be used by calling code.

## The Main Commands

The following table shows the list of public commands exported from the Loopz module:

| COMMAND-NAME                                                                     | DESCRIPTION
|----------------------------------------------------------------------------------|------------
| [Invoke-ForeachFsItem](Elizium.Loopz/docs/Invoke-ForeachFsItem.md)               | Invoke a function foreach file system object
| [Invoke-MirrorDirectoryTree](Elizium.Loopz/docs/Invoke-MirrorDirectoryTree.md)   | Copy a directory tree invoking a function
| [Invoke-TraverseDirectory](Elizium.Loopz/docs/Invoke-TraverseDirectory.md)       | Navigate a directory tree invoking a function
| [Write-HostFeItemDecorator](Elizium.Loopz/docs/Write-HostFeItemDecorator.md)     | Write output foreach file system object

## Supporting Utilities

| COMMAND-NAME                                                                     | DESCRIPTION
|----------------------------------------------------------------------------------|------------
| [Select-FsItem](Elizium.Loopz/docs/Select-FsItem.md)                             | A predicate function used for filtering
