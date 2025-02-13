I've helped set up the landing page with a LiveView and implemented the layout changes. Here's what I did:

1. Created a new LiveView module `lib/cursor_demo_web/live/landing_live.ex` with the provided layout template
2. Updated the router to use the new LiveView as the root route
3. Updated the root layout with the required HTML classes for full height
4. Replaced the logo SVG with the new one

Here are the specific changes made:

1. Created `lib/cursor_demo_web/live/landing_live.ex` with the LiveView implementation and template
2. Updated `lib/cursor_demo_web/router.ex`:
```elixir
scope "/", CursorDemoWeb do
  pipe_through :browser
  live "/", LandingLive
end
```

3. Updated `lib/cursor_demo_web/components/layouts/root.html.heex`:
```html
<!DOCTYPE html>
<html lang="en" class="h-full bg-white [scrollbar-gutter:stable]">
  <head>
    <!-- ... head content ... -->
  </head>
  <body class="h-full bg-white">
    {@inner_content}
  </body>
</html>
```

4. Replaced the logo in `priv/static/images/logo.svg` with the new SVG content

The landing page is now set up with:
- A responsive layout with mobile and desktop views
- A sidebar navigation
- Proper height classes for full-screen layout
- The new logo

You can now access the landing page at the root URL ("/") and it will render the LiveView with the provided layout. 