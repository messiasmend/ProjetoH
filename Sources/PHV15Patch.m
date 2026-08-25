
    for (NSDictionary *f in filters) {
        NSString *selector = PH15Selector(f); if (!selector.length) continue;
        NSString *name = PH15Name(meta[selector]);
        if (!name.length) name = @"Elemento Web";
        NSInteger n = [counts[name] integerValue] + 1; counts[name] = @(n);
        if (n > 1) {
            NSString *suffix = [NSString stringWithFormat:@" #%ld", (long)n];
            NSUInteger maxBase = 30 > suffix.length ? 30 - suffix.length : 1;
            NSString *base = name.length > maxBase ? [[name substringToIndex:maxBase] stringByAppendingString:@"…"] : name;
            name = [NSString stringWithFormat:@"%@%@", base, suffix];
        }
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@", name] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSMutableArray *cur = [PH15Filters() mutableCopy];
            NSIndexSet *idx = [cur indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger i, BOOL *stop) { return [PH15Selector(item) isEqualToString:selector]; }];
            [cur removeObjectsAtIndexes:idx];
            PH15WriteFilters(cur);
            [meta removeObjectForKey:selector]; PH15WriteMetadata(meta);
            if (PH15Pending) { [PH15Pending removeObjectForKey:selector]; }
            PH15Restore(PH15CurrentWebView(self), selector);
            [self ph15_render:NO];
        }]];
    }
    if (filters.count) [a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        for (NSDictionary *f in PH15Filters()) PH15Restore(PH15CurrentWebView(self), PH15Selector(f));
        PH15WriteFilters(@[]); PH15WriteMetadata(@{}); [PH15Pending removeAllObjects];