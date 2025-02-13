1. **Users**:
   - Do you want to implement any specific authentication system (like Guardian/JWT) or stick with Phoenix's built-in authentication?
   
   built in is fine for now, i will think more about this later
   
   - For the profile, should it be a separate table or embedded in the users table with fields like bio, location, website?
   
   whatever makes more sense in our case
   
   - Should we track user registration/last login dates?
   
   timestamping models is always smart

2. **Posts**:
   - Besides the 280-char message, should we support:
     - Media attachments (images/videos)?
     
     images would be nice, but keep it simple
     
     - Post visibility (public/private)?
     
     no, not yet
     
     - Reply functionality (threads)?
     
     yes
     
     - Repost/Quote functionality?
     
     not yet.

3. **Likes**:
   - Should we track when a like was created?
   
   yes
   
   - Do we need to implement unlike functionality?
   
   yes
   
   - Should users be able to see who liked their posts?
   yes

4. **Follows**:
   - Do you want to implement blocking functionality?
   not yet
   
   - Should users be able to have private accounts where they need to approve followers?
   not yet
   
   - Do we need to track when the follow relationship was created?
   yes

5. **General**:
   - Do you want soft deletion for any of these entities?
   yes
   
   - Should we implement any rate limiting (e.g., max posts per hour)?
   not yet
   
   - Do you want to implement notifications for likes, follows, and mentions?
   yes

Mind that I wish to avoid message passing when we start with the ui everything should be pubsub as much as possible, lets implement broadcast functions where needed in advance. 