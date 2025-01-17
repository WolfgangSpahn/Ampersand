# The RULE statement

## Purpose

The purpose of a rule is to constrain data. Refer to the chapter about rules in the tutorial for examples and a practice-oriented explanation.

A rule statement defines something that should be true. It does not define the enforcement.

## Syntax of rules

A `<rule>` has the following syntax:

```text
RULE <label>? <term> <meaning>* <message>* <violation>?
```

Terms and operators are discussed in [a separate section](terms/):

## Syntax of labels

A `<label>` is optional. It can be a single word or a string \(enclosed by double brackets\) followed by a colon \(`:`\).

### MEANING\*

The meaning of a rule can be written in natural language in the Meaning part of the RULE statement.  
It is a good habit to specify the meaning! The meaning will be printed in the functional specification.  
The meaning is optional.

#### Syntax

```text
MEANING {+<text>+}
```

The `<text>` part is where the the meaning is written down. It is enclosed by `{+` and  +`}` and may be spread across multiple lines. If you need specific markup, turn to [this page](meaning-statements.md) for a full explanation.

### MESSAGE\*

Messages may be defined to give feedback whenever the rule is violated. The message is a string. When you run your prototype this is printed in a red box when the rule is violated. You will see the violations by clicking on that message.

```text
MESSAGE String
```

### VIOLATION

A violation message can be constructed so that it gives specific information about the violating atoms:

```text
VIOLATION (Segment1,Segment2,... )
```

Every segment must be of one of the following forms:

* `TXT` String
* `SRC` Term
* `TGT` Term

A rule is violated by a pair of atoms \(source, target\). The source atom is the root of the violation message. In the message, the target atoms are printed. With the Identity relation, the root atom itself can be printed. You can use a term to print other atoms. Below two examples reporting a violation of the rule that each project must have a project leader. The first prints the project's ID, the second the project's name using the relation projectName:

`VIOLATION ( TXT "Project ", SRC I, TXT " does not have a projectleader")`

`VIOLATION ( TXT "Project ", SRC projectName, TXT " does not have a projectleader")`

## ROLE MAINTAINS

By default, rules are invariant rules.  
By preceding the rule statement with a role specification for this rule, the rule becomes a process rule.

tbd

