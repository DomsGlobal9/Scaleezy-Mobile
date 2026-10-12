/// What to say when a role does not reach a screen, as the website's `lib/permissionText.js`:
/// the heading names what the person wanted to do, the line says which permission to ask for.
library;

/// "pick orders" reads "You cannot pick orders"; without one, the plain heading.
String noAccessTitle(String? what) =>
    what == null ? 'Not part of your role' : 'You cannot $what';

String noAccessMessage(String? permission) =>
    _ask[permission] ??
    "This part of the app isn't part of your role. Ask whoever manages your team if you need it.";

const _team = 'Ask whoever manages your team for the permission to';
const _owner = 'Ask the shop owner: only an owner or admin';

const Map<String, String> _ask = {
  'shelf:putaway': '$_team put stock away and move it.',
  'shelf:view': '$_team see the shelves.',
  'shelf:manage': '$_team set up racks and shelves.',
  'inventory:view': '$_team see stock.',
  'inventory:adjust': '$_team change stock.',
  'inventory:transfer': '$_team move stock between stores.',
  'stock_count:view': '$_team work with stock counts.',
  'product:view': '$_team see products.',
  'product:create': '$_team add products.',
  'sales_order:view': '$_team see orders.',
  'sales_order:counter_sale': '$_team sell at the counter.',
  'purchase_order:view': '$_team see purchase orders.',
  'purchase_order:create': '$_team raise purchase orders.',
  'supplier:view': '$_team see suppliers.',
  'customer:view': '$_team see customers.',
  'offer:view': '$_team see offers.',
  'offer:create': '$_team make offers.',
  'return:view': '$_team see returns.',
  'admin:locations': '$_owner sets up stores and godowns.',
  'admin:users': '$_owner manages the team.',
  'admin:roles': '$_owner changes what each role can do.',
};
