# App-to-website release checklist

Use this checklist whenever Mera Markaz changes.

1. Update the Flutter version in `E:\Projects\Pakistani App\pubspec.yaml`.
2. Store approved app screenshots in `E:\Projects\Pakistani App\assets\screenshots`. Do not include real user information.
3. Run `npm run sync:app` in this website project.
4. If a feature was added, removed or renamed, update the home-page feature description and the relevant guide section.
5. If data collection, Firebase use, Gemini use, permissions, account deletion or retention changed, review `/privacy`, `/data-safety`, `/account-deletion` and the Google Play Data Safety form together.
6. If sign-in or guest-session behaviour changed, update the user guide and support page.
7. Run `npm run build` and open every public policy URL.
8. Deploy the website before submitting the related Play Store release.
9. Confirm the support email shown on the Play listing is active and monitored.

## Automatic deployment options

For one-click updates, connect this folder to a GitHub repository and import it into a hosting provider. Each push will rebuild the website, and the build automatically synchronises the sibling app when both projects exist in the build environment.

For separate repositories in cloud hosting, use a deployment hook from the Flutter app repository: after an app change, copy/update the public website data and trigger the website deployment. Never place signing keys, Firebase secrets, API keys, user data or internal security reports in the website repository.
