# Project Meeting Notes - Fall 2025

## Meeting: September 3, 2025

**Members Present:** Ross, Nick (online), Ben, Dylan, Harry, Camille

### Summary
Went over the requirements checklist together and read through the requirements document to find areas that need clarity, problems that might creep up in the process, different integration systems we might need. Made a meeting with Dr. Zeng to help us clarify what needs to be addressed now for the document.

---

## Meeting: September 8, 2025

**Members Present:** Ross, Nick (online), Dylan, Harry, Camille

### Summary
Met with Dr. Zeng to go over requirements and clarifications for what is being asked for this document.

### Key Points
- Have a list of the documents needed to submit for phase 1
- Timeline of when the items are started/finished, assign a person on the deliverable
- WRS is major part of phase 1, put people in charge of sections on the WRS
- Pick apart the project specification (we have done this already), identify the issues (which also includes something that might be missing from the pdf)
- Find solutions to questions we have in the document, and that is what goes in the Project Plan
- It might be a privacy issue if the phone is using voice to tell directions (people can know where the blind user would be traveling to), solutions could be use headphones or vibration of the phone

### Section Assignments
- **1.1-1.2:** Nick
- **1.3-1.5:** Camille
- **2.1-2.3:** Ross
- **3.1-3.3:** Harry, Ben
- **4.1-4.2:** Dylan

---

## Meeting: September 10, 2025

**Members Present:** Ross, Harry, Dylan, Nick (online), Ben, Camille

### Summary
Reviewed the draft document. Read through each section together and determined editing or adding to the document.

### Overall Fixes
- Formatting
- Table of contents needs updated
- Some pages need adjusting for uniformity (i.e. page 2 is bolded and looks different than page 1)

### Section 1
- **Section 1.1:** Looks good as is. Possibly some formatting for uniformity. Bullet, dash, etc.
- **Section 1.2:** No comments
- **Section 1.3:** Added AS-4, AS-5 that we assume the user is within the range defined as a legally blind person and they have a caretaker. Constraint added CO-5: no funding. Optional feature: network connection.
- **Section 1.4:** Look for other apps that might be sources for ours
- **Section 1.5:** Looks good

### Section 2
- **Section 2.1:** Decided on process model – Spiral Model
- **Section 2.2:** Discussing optional communication tools, more professional than discord (Jira, DevOps, etc.)
- **Section 2.3:** We aren't sure how to classify owner to deliverable. Added and assigned numerous roles to people. People can add roles if they feel they want to add more

### Section 3
- **Section 3.1:** Add our schedule, when we meet, how we meet. Wednesdays hybrid meeting.
- **Section 3.2:** Spelling and grammatical errors.
- **Section 3.3:** Separate document for risk management.

### Section 4
- **Section 4.1:** Added having an actual visually impaired person to be able to test our project if possible
- **Section 4.2:** It's empty. It needs to be filled. Some ideas tossed in.

### Next Steps
Agreed to either meet Friday after these changes have been addressed, or simply use Discord to give the final ok.

---

## Meeting: September 12, 2025

**Members Present:** Ben, Dylan, Harry (via phone), Nick, Camille, Ross

### Summary
Going over final details before hand-in. Agreeing on font type, size, bullet points or dashes.

### Decisions
- Everyone will go over their own section and do typeface Arial, size 11, bullet points.
- Discussed formatting for references
- Camille will hand in the repo link for our GitHub project and the pdf of the preliminary plan
- She will also make sure the documentation is in the root of the GitHub repo into a folder named "Docs"

---

## Meeting: September 24, 2025

**Members Present:** Dylan, Harry, Nick, Camille, Ross

### Summary
Slides, meeting notes, refactored plan, WRS → due October 12th

### WRS Suggestions
- (Nick) Look at document, look at 3 sections for WRS (find 3-4 problems)
- (Ross) Pick a section
- (Nick) Everyone has gone through it (the document) and left a couple comments on the file

### Revisions via Dr. Zeng's Suggested Feedback
- Dylan's section → deliverables need to match up
- Ross' section → Table is Section 2 isn't needed
- "Finally, a good idea would be to include a rough timeline built around the due dates as checkpoints for the owners to monitor the progress."

### TODO
- Add a timeline to deliverables sections around checkpoints
- Update draft with above changes (deliverables tables need to match and section 2 table can be removed)

### Slides
- Modify template given (Camille)

### WRS Rough Draft Assignments
- **Section 1:** Introduction (Nick)
- **Section 2:** All the problems (Ross)
- **Section 3:** Problem Goal (improved understanding of requirements) (can't do until 2 is done)
- **Section 4:** Prototype and user manual (Dylan + Harry)
- **Section 5:** Traceability (Ben)

### Next Steps
- Set up a meeting with Bolong next week: Monday the 29th at 12:30
- Camille will set up a meeting with Bolong Monday the 29th at 12:30
- Do some of your section on the WRS and slides
- Solidify more after Bolong's meeting
- Meeting with Bolong: confirmation and presentation explanation

---

## Meeting: September 28, 2025 (Session 1)

**Members Present:** Camille, Ross, Harry, Nick, Ben

### Notes from Ross
- 3 pairs of scenarios that represent 3 features
- Prototype: implement something about one feature
- Put mockup deliverables (GUI sketch, speech commands, etc.) in the 4.2 table. 4.2 table can be the expanded table with more detailed information on who does what part of the assignment.

---

## Meeting: September 28, 2025 (Session 2)

**Members Present:** Camille, Ross, Harry, Nick, Ben

### Today's Agenda

#### As-Is & To-Be Scenarios (Pick 3 and pick 1 priority ✨)
Current state without the solution (aka without our app, what is the current state for visually impaired people). Each situation has to be a different case: so first is for navigation, second situation

**Scenarios:**
- As-Is: Knowing Braille, having a helper person, or asking for support (help desk)
- As-Is (given) / To-Be
- As-Is (Harry): Avoiding obstacles - specifically a trash can
  - To-Be: App alert user for obstacle ahead
- ✨ **As-Is:** Falling down, phone possibly not within hand
  - **To-Be:** Call emergency services if needed, beep to know where phone is (~60 sec) and possibly text emergency services and call caregiver (send location to caregiver), and this way if 911 is called, location is already available.

**Resource:** Dr. Beaty: https://business.wsu.edu/granger-cobb-institute-for-senior-living/ (Nancy Swanger) might have ideas

#### Meeting with Bolong
- Set up for October 9th @ 11:30 (email sent, awaiting confirmation)
- Mistakenly set meeting for 12:00 in email. Corrected: awaiting Bolong response.

#### WRS Discussion
- Some discussion: 2.1.1 with outside ranges and what boundaries will be enclosed within the "building" parameters but are considered outside or courtyard, etc.
- How will caretaker be involved with the app? Let the caretaker configure the app for the visually impaired person.
- 2.1.4: Lots of discussion about the priority situation and how that will be working. Automatic calling/texting, gyroscope for falling notifications.
- Detect obstacles, when to place the emergency calls, "next actions" (choose route and choose when it's done), possible to use as a background app?, can set to avoid stairs

#### Divide Tasks & Set Due Date
Goal is to get everything in by Monday the 6th for Bolong to look over our rough draft.

**Tasks:**
- **Camille** - Slideshow
- **WRS** - Everyone keep their sections, maybe shorten Ross' section and Nick to add to theirs. Dylan, Ben, and Harry are all still working on their sections.

**WRS Rough Draft Sections:**
- **Section 1:** Introduction (Nick)
- **Section 2:** All the problems (Ross)
- **Section 3:** Problem Goal (improved understanding of requirements) - can't do until 2 is done (Nick + Ross)
- **Section 4:** Prototype and user manual (Dylan + Harry)
- **Section 5:** Traceability (Ben)

**UI Sketch Person:** (Dylan + Harry: Section 4) Swipe gestures (up is an action, down), or panels like a text pops up and you can swipe for confirmations or taps, audio confirmation

---

## Meeting: October 8, 2025

**Members Present:** Camille, Ross, Harry, Nick, Ben, Dylan

### Summary
Went over the presentation together. Wording on Slide 7 was odd and needs improvement, agreed to have both tables on the presentation. Assigned slides to people for presentation purposes.

Moved onto the WRS. Section 1 was found to be too long and looking to make cuts. Have to reformat to match the template: i.e. WRS need tables, etc.

### TO DO FOR EVERYONE
- **Nick:** Finish up section 3
- **Ross:** Migrate some of the content: do some changes for section 3: rewording. New format, tables and such. Have everyone work on the old format and we will transfer it to the new format.
- **Ben:** Section is good, helping reformat
- **Harry:** Working on UI with Dylan, maybe refine user manual
- **Camille:** Presentation fix slide 7, harry put the exact words and add both tables

---

## Meeting: October 9, 2025

### Presentation Discussion

**Prototype Requirements:**
Prototype that can do something for each of these scenarios

**Fall Detection:**
- Easiest, shake it to show it can bring up the screen → bring up the options → call someone's number (not the actual emergency services)
- Can dig deeper into the back end if we have time, but this is the focus for the documents and requirements, how to actually help someone in that situation

### Discussion with Bolong

**Nick's Question:** Phase 2 → more documentation?

**Bolong's Response:** A little bit. Phase 2 → post something on canvas that will include a few new requirements that will incorporate into the existing WRS and a new technique (use a KAOS model to build requirements models) so do it all over again using a different tool

**Key Points:**
- These scenarios are the basis: show the scenario again and the demo for the final
- Relying on tap is not very reliable as we just witnessed so maybe utilize physical buttons (volume, etc.) or gestures (draw something), voice feedback alternative → haptic feedback
- Instead of feedback have a vibrate → one is left, twice is right

---

## Meeting: October 11, 2025

**Members Present:** Ross Kugler, Huy (Harry) Ky, Dylan Gyori, Camille Orego

### Summary
Impromptu meeting. Going over the WRS document to fill out 4.2 (4.2.1, 4.2.2, and 4.2.3)

### Issues Identified
- Some discussion over whether we need to add to the prototypes to reflect the functional requirements for cross platform
- FR7 and FS7 is missing, remapped FR12 and FS12 to be 7
- P6 is not mapped to anything in the document: might want to readdress it
- Appendix is empty
- Beeping feature for a dropped phone is mentioned in the presentation, and emergency services is noted to vaguely having haptic and audio feedback, so that might be able to be modified to address the beeping feature. But worried about having that pull a double duty.
- Created new goal G11

### Deliverables Review

**1. WRS document**
- Including a mockup (sketch + descriptions of user interfaces: GUIs, speech commands, etc.) and basic user manual. These could be included in a separate file from the WRS if you choose to.
  - ✅ Work in progress
- This document should include the "Issues" and "Improved Understanding" portions of the Phase I submission.
  - ❓ Wut?

**2. Revised Phase I plan based on your preliminary plan.**
- ❓ Did we make the changes suggested?

**3. A collection of your meeting records.**
- This could be one single document, a zip package of documents, or a link to your google doc/drive address, etc.
  - ✅ Just need to drop this document, reformatted, into the repo.

**4. PowerPoint slides you use for your presentation.**
- ✅ Already in the repo

### Action Items
- Revise the Prelim Plan for a finalized Phase 1 plan deliverable
- Figure out what "Issues" and "Improved Understanding" means
- Read over the WRS
  - Revisit P6 since it doesn't map anywhere
  - Align the beeping feature from the presentation to the WRS (G11)
  - Add to Appendix?
  - Add to the prototypes (cross platform functionality)?
- Readjust the README
  - Include a link in the README to the cloud location for outlook collab

### Final Note
Assuming we get all the above finished by tomorrow, Camille will hand in the repo with the final commit hash.