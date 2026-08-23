import {
  loadDispatchQuoteV2Files as loadBaseFiles,
  transformDispatchQuoteV2Foundation as transformBase,
} from './dispatch_quote_v2_foundation_transform_v2.mjs';

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function pruneRetiredDashboardQuoteEditor(input) {
  let source = input.replace(/\r\n/g, '\n');
  const marker = '\nclass _DispatchQuoteDialog extends StatefulWidget {';
  const index = source.indexOf(marker);

  if (index >= 0) {
    source = `${source.slice(0, index).trimEnd()}\n`;
  }

  const retiredMarkers = [
    'class _DispatchQuoteDialog extends StatefulWidget',
    'class _DispatchQuoteDialogState extends State<_DispatchQuoteDialog>',
    'class _QuoteSection extends StatelessWidget',
    'class _QuoteTotalCard extends StatelessWidget',
    'class _RoutePlanningNotice extends StatelessWidget',
  ];
  for (const retired of retiredMarkers) {
    if (source.includes(retired)) {
      fail(`Retired dashboard quote editor remains after Quote V2 transform: ${retired}`);
    }
  }
  if (!source.includes('MarketplaceDispatchQuoteForm.show(')) {
    fail('Dashboard reusable Quote V2 form wiring was lost while pruning retired editor code.');
  }
  return source;
}

export function transformDispatchQuoteV2Foundation(files) {
  const transformed = transformBase(files);
  const result = {
    ...transformed,
    dashboard: pruneRetiredDashboardQuoteEditor(transformed.dashboard),
  };

  const secondBase = transformBase(result);
  const second = {
    ...secondBase,
    dashboard: pruneRetiredDashboardQuoteEditor(secondBase.dashboard),
  };
  for (const key of Object.keys(result)) {
    if (second[key] !== result[key]) {
      fail(`Quote V2 v3 transform is not idempotent for ${key}.`);
    }
  }
  return result;
}

export function loadDispatchQuoteV2Files() {
  return loadBaseFiles();
}
