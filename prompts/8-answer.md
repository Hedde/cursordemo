I'll help you design the data model for your Twitter-like application. Before implementing, let me ask some clarifying questions to ensure we create the right structure:

1. **Users**:
   - Do you want to implement any specific authentication system (like Guardian/JWT) or stick with Phoenix's built-in authentication?
   - For the profile, should it be a separate table or embedded in the users table with fields like bio, location, website?
   - Should we track user registration/last login dates?

2. **Posts**:
   - Besides the 280-char message, should we support:
     - Media attachments (images/videos)?
     - Post visibility (public/private)?
     - Reply functionality (threads)?
     - Repost/Quote functionality?

3. **Likes**:
   - Should we track when a like was created?
   - Do we need to implement unlike functionality?
   - Should users be able to see who liked their posts?

4. **Follows**:
   - Do you want to implement blocking functionality?
   - Should users be able to have private accounts where they need to approve followers?
   - Do we need to track when the follow relationship was created?

5. **General**:
   - Do you want soft deletion for any of these entities?
   - Should we implement any rate limiting (e.g., max posts per hour)?
   - Do you want to implement notifications for likes, follows, and mentions?

Let me know your preferences on these points, and I'll help design and implement the appropriate schemas and migrations. We can start with the core functionality and add more features incrementally. 