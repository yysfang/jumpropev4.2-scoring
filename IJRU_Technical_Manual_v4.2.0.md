# IJRU Technical Manual v4.2.0

> **Source:** https://rules.ijru.sport/technical-manual/
> **Version:** 4.2.0
> **Author:** International Jump Rope Union (IJRU)

This document is a compilation of the complete IJRU Technical Manual and all sub-pages.

---

# 1. Technical Manual: Technical Manual

The Technical Manual (TM) contains detailed technical specifications of concepts like scoring and results.

---

# 2. Calculations (Overview): Score calculations and results

The goal of this chapter is to be easily understood by the wider community of our sport as well as  being clear and accurate as to leave no questions on how the calculations will be implemented. To meet both goals, some sections will be accompanied by an expansion panel containing examples and simplified explanations using less math formulas.

## Averaging

If there are two judges of a type, the two scores are averaged.

**Example**

|| Judge 1 | 112 |
Judge 2 | 114 |

Gives an average of $\frac{112 + 114}{2} = 113$$\frac{115 + 118 + 119}{3} = 117.33$$R$$D$$P$$M$$F_p$$L(x)$$R$$R = \frac{\lfloor R * 100 \rceil}{100}$R=100⌊R∗100⌉

---

# 3. Freestyle Calculations: Calculating freestyle event scores

There are several types of freestyles, all with differing scoring methods. You can explore them in the pages linked below.

## 📄️ Calculating Single Rope freestyle scores

Single Rope freestyle scores are based on a cumulative difficulty model where presentation, required elements, and deductions can affect the score.

## 📄️ Calculating Double Dutch freestyle scores

Double Dutch freestyle scores are based on an average routine difficulty level where presentation, required elements, and deductions can affect the score.

## 📄️ Calculating Wheel freestyle scores

Wheel freestyle scores are based on a cumulative difficulty model where presentation, required elements, and deductions can affect the score.

## 📄️ Calculating Show Freestyle scores

Show Freestyle scores are based on a cumulative Difficulty model where Presentation, Required Elements, and Deductions can affect the score.

## 📄️ Calculating DDC freestyle scores

Every judge's base score is calculated the same basic way regardless of the judge type.

---

# 4. Ranking Calculations: Calculating the ranking

## Speed events

The entry with the highest result ($R$$m$$R$$n$$n$$R$$n + m$$m = 3$$n$$m$$4 + 3 = 7$$R$$R$$M$$Q$$P$$D$$m$$n$$n$$R$$n + m$$R$$m$$R$$n$$n$$R$$n + m$$B_s$$S$$1 + 2 + 3 = 6$$T$$R$$R_{max}$$R_{min}$$N$$N$$B$B) The athlete/team with the highest total normalized score is ranked first in the tie, the second best total normalized score is ranked second and so on.

---

# 5. Results Calculations: The results

All published results must be accompanied with details identifying the event(s), and athlete(s) or team(s).
Each athlete/team should have a unique id, name/team name, country/club, and, for team events, names of the athletes competing the event published with their results.

Scores that are used as multiplication factors should preferably be written as a percentage and not as a factor, it is advised to write for example $-10 \%$$0.9$$+17 \%$$1.17$$R$$S$$R$$D$$P$$Q$$M$$S$$R$$N$$B$$S$$T$$S$$N$$B$B are optional (they must be published if a tie had to be resolved in that Overall category)

---

# 6. Speed Calculations: Calculating speed and multiples scores

Scores are collected from each judge and averaged according to [the averaging rules](/technical-manual/calculations/#averaging).

This average is called $a$$m$$m = (\text{starts} + \text{switches}) \times 10$$m = (\text{starts} + \text{obstructions}) \times 5$$R$$m$$a$$R = a - m$R=a−m)

---

# 7. Specifications (Overview): Specifications

Specific information regarding the timing, tones and call outs are detailed in Specifications.

---

# 8. Timing Tracks: Signals, sounds and call outs

## Timing

All time durations in this specification are measured relative to the start of the `start-BEEP`/`ddc-GO` in the beginning of the time track and is measured until the start of another sound.

## Tones

`start-BEEP`
Defined as a square wave at 578.3 Hz, this correlates do a D5 in standard tuning (A = 440 Hz) playing for 0.350 seconds.
`switch-BEEP`
Defined as a square wave at 493.9 Hz, this correlates to a B4 in standard tuning (A = 440 Hz) playing for 0.350 seconds.
`soft-BEEP`
Defined as a sine wave at 578.3 Hz for 0.350 seconds.
`ddc-GO`
Defined as the spoken word "Go!"
`ddc-BUZZ`
Defined as a buzzing sound

## Start

All speed time tracks except DDC should start as follows:

`<Event Name> <Event Time> <1.000 seconds silence> Judges Ready? <0.500 seconds silence> Athletes Ready? <0.500 seconds silence> Set <0.500 seconds silence> <start-BEEP>`

Where `<Event Time>` is defined as `[<N> by] <Time>` seconds" where `[<N> times]` is only required if
the event is performed in a relay fashion. (For example: "four by thirty seconds" or "one hundred
eighty seconds") All time definitions in the event presentation come in seconds.

The `<Event Name>` is stated as defined in the [competition manual](/competition-manual/).

DDC speed time tracks start as follows:

`Double Dutch Contest. Speed. Judges ready? Jumpers ready? On your mark. Get set. <ddc-GO>`

For freestyle events, after the athlete has been introduced, their music will begin after a short pause.

## Switch

When the defined amount of time has elapsed since the beginning of the previous `start-BEEP`/`switch-BEEP`
and another athlete’s part of a relay fashion event should commence a `switch-BEEP` should sound.

## Stop

When the defined amount of time has elapsed since the beginning of the previous `start-BEEP`/`switch-BEEP` and the event should stop a `start-BEEP` should sound.

For DDC the `ddc-BUZZ` should sound instead.

## Time call outs

For speed and multiple events where each section of the event is shorter than or equal to 60 seconds in duration there should be time call outs every 10 seconds in the form of `<Seconds>` where `<Seconds>` is the number of seconds elapsed since the previous `start-BEEP`/`switch-BEEP`.

For DDC speed events the time call outs are made as a count-down rather than a count up. The time call outs should be in the form `<Seconds Left>` where `<Seconds Left>` is the number of seconds left until the next `ddc-BUZZ`. Time call outs should be made 10, 5, 4, 3, 2, and 1 second before the `ddc-BUZZ`.

For speed and multiple events where each section of the event is longer than 60 seconds in duration there should be time call outs every 60 seconds in the form of `<Minutes> minute(s)` where `<Minutes>` is defined as the number of minutes elapsed since the last `start-BEEP`/`switch-BEEP`.
In addition to this there should be call-outs every 15 seconds in the form of `<Seconds>` where `<Seconds>` is the number of  seconds elapsed since the previous `start-BEEP`/`switch-BEEP` or minute call-out.

---
