# hackwestex27
TTU HackWesTex 2027 Developer Challenge: macOS AI File System Metrics

## Introduction

One the hidden challenges of running AI models on non-cloud infrastructure is the ability to support 
the scalable data storage requirements of the users.  Healthcare professionals, law firms and 
other private companies may store terabytes or petabytes of data at rest in structured file systems.  
Managing these file systems is largely relegated to mixtures of basic open source tools and highly 
proprietary/file system specific tools designed to run in Linux or BSD (see ZFS pooling).

Recently, developers and users of private AI infrastructure have discovered the power efficiency and 
performance of Apple Silicon to run local AI models.  Workflows such as OpenClaw and Exo have become 
commonplace is small organizations seeking to free themselves for cost prohibitive cloud-based AI 
tools.  However, there are minimal tools available to manage and monitor file systems on macOS 
systems.  

This challenge is designed to build a set of management and monitoring tools natively developed 
for macOS to manage file systems.  We challenge the students to explore ideas and implementations 
for management utilizes that: 
  * monitor the health of file systems, including the backing block storage health
  * monitor the performance (GB/s) of the file system I/O performance
  * monitor the capacity and per-user quotas present for a given file system
  * display the metrics in a useful form the administrators 
  * provide reporting mechanisms to alert administrators of nefarious users and/or capacity concerns
  * support local (APFS) and shared (NFS,pNFS) volumes

## Rules

Challenge teams can use mixtures of any programming models natively available on macOS.  This includes 
Python, Swift, C++, C, Rust, Go, etc.  All source code and documentation must be available open source 
at the time of submission.  The source MUST include instructions to build and execute the tools.  
Makefiles and/or CMake scripts are highly encouraged in order to ensure portability.  Apple XCode or 
MS VSCode is not required, but can be used to assist in the development.

The final deliverables should be:
  * The repository of source code, including basic documentation to build + execute the project
  * A short demo of the functionality
  * Additional points will be given for projects that also outline "future work" to expand the scope of the tools

## Judging

Judging will be done Sunday September 13th at the end of the event.  The winning team will 
be presented with a prize (to be announced at the start of the event).

## Source Control

The source code for the project must be stored in a publicly available repository such as Gitlab, Github 
or Bitbucket for judging.  Source code storage locally on the teams' personal devices will not 
be accepted.
