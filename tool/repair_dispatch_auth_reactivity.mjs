import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const target = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_page.dart',
);

const source = fs.readFileSync(target, 'utf8');

if (
  source.includes('FirebaseAuth.instance.authStateChanges()') &&
  source.includes('Widget _buildAuthenticatedDispatch(BuildContext context)')
) {
  console.log('Dispatch auth reactivity repair is already applied.');
  process.exit(0);
}

const oldAnchor = `  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text('Sign in to use Dispatch.'));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
`;

const newAnchor = `  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting &&
              !authSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authSnapshot.data == null) {
            return const Center(child: Text('Sign in to use Dispatch.'));
          }
          return _buildAuthenticatedDispatch(context);
        },
      );

  Widget _buildAuthenticatedDispatch(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
`;

if (!source.includes(oldAnchor)) {
  throw new Error(
    'Dispatch auth guard anchor was not found. No product file was changed. ' +
      'Upload the current marketplace_dispatch_page.dart before attempting another repair.',
  );
}

const updated = source.replace(oldAnchor, newAnchor);

if (
  !updated.includes('FirebaseAuth.instance.authStateChanges()') ||
  !updated.includes('Widget _buildAuthenticatedDispatch(BuildContext context)') ||
  updated.includes('if (FirebaseAuth.instance.currentUser == null)')
) {
  throw new Error('Dispatch auth reactivity postcondition failed.');
}

fs.writeFileSync(target, updated, 'utf8');
console.log('Dispatch now listens to Firebase Auth state changes.');
console.log('Existing provider/customer Dispatch behavior was left in place.');
