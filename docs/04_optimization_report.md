# Phase 4: Query Optimization

## How we measured

We added indexes for queries that were reading many rows to find only a few. We also rewrote a few queries where the filter or join made PostgreSQL do extra work. The indexes are in `sql/05_indexes.sql`, and the changed queries are in `sql/06_optimized_queries.sql`.

We ran every query five times with `EXPLAIN (ANALYZE, BUFFERS)`. The write queries ran inside `BEGIN` and `ROLLBACK`, so the seed data stayed the same. The full plans and the averages are saved in [`benchmarks/results/optimized/`](../benchmarks/results/optimized/).

The optimized run used PostgreSQL 18.4, while the Phase 3 baseline used PostgreSQL 18.6. Both runs used the project laptop and the same seed data. Timing differences may reflect the PostgreSQL version as well as the indexes, especially when the change is small.

## Results

Improvement is calculated as `(before - after) / before * 100`. The before column uses the Phase 3 averages; the after column uses the five-run averages from the optimized plans.

| Query | Before (ms) | What we changed | After (ms) | Improvement | Same result? |
|---|---:|---|---:|---:|:---:|
| R01 | 5.273 | Member 1023’s current position needed a search through all positions. We added a member lookup index. | 0.072 | 98.6% | Yes |
| R02 | 3.266 | Finding one member’s positions used a full scan. The new index also keeps them in start-date order. | 0.053 | 98.4% | Yes |
| R03 | 2.426 | The OR across both connection columns made the reverse lookup expensive. We split it into two lookups. | 0.041 | 98.3% | Yes |
| R04 | 9.044 | Both sides of the mutual-connection check scanned the table. We split each side into indexed lookups. | 0.073 | 99.2% | Yes |
| R05 | 24.042 | The second-degree search used an OR join over connections. We look up each endpoint separately. | 0.199 | 99.2% | Yes |
| R06 | 5.686 | The posted-date index helps narrow and order the jobs; the title substring still has to be checked. | 0.200 | 96.5% | Yes |
| R07 | 4.872 | We added an index for jobs by required skill and a smaller index of open jobs. | 0.737 | 84.9% | Yes |
| R08 | 0.206 | The existing unique index on job and member already supports this lookup. | 0.063 | 69.4% | Yes |
| R09 | 1.774 | Applications were not indexed by member. The new index also returns them newest first. | 0.054 | 97.0% | Yes |
| R10 | 2.311 | The new partial index contains pending invitations and is ordered by recipient and send time. | 0.056 | 97.6% | Yes |
| R11 | 4.523 | We added an index on the viewed member and time, with viewer IDs included. | 0.066 | 98.5% | Yes |
| R12 | 4.592 | A partial index on current positions helps find employees at a company. | 0.129 | 97.2% | Yes |
| R13 | 19.997 | We changed NOT IN to NOT EXISTS to avoid the NULL problem. The old query returned no members. | 10.200 | 49.0% | Fixed NULL issue |
| R14 | 8.282 | A partial index helps find hires by status update time. | 2.668 | 67.8% | Yes |
| R15 | 8.430 | We changed the year check to a start and end time range so the date index can be used. | 6.929 | 17.8% | Yes |
| R16 | 1.530 | The posted-date index helps narrow the jobs with salary information. | 1.185 | 22.5% | Yes |
| R17 | 34.305 | The member and start-date index supplies positions in the order needed by LEAD. | 30.351 | 11.5% | Yes |
| R18 | 7.839 | An index on skill and endorsement count helps rank members with the SQL skill. | 2.313 | 70.5% | Yes |
| R19 | 217.864 | The original query ran two subqueries for every company. The new query counts jobs and applications by company once. | 2.952 | 98.6% | Yes |
| R20 | 6.322 | We changed the date cast in the filter to a time range, allowing an index lookup. | 1.091 | 82.7% | Yes |
| R21 | 81.391 | We find the top member for each skill using the endorsement-ranked index. | 0.273 | 99.7% | Yes |
| R22 | 29.166 | The new descending application-time index avoids sorting the whole table for this page. | 5.861 | 79.9% | Yes |
| R23 | 8.697 | We added an index on lower(email), matching the sign-in filter. | 0.021 | 99.8% | Yes |
| R24 | 8.732 | The invitation time index helps filter 2026 invitations and find their senders. | 6.646 | 23.9% | Yes |
| R25 | 31.940 | The member and start-date index supplies rows in the order needed by LAG. | 27.897 | 12.7% | Yes |
| W01 | 0.607 | The existing unique index checks the conflict; no additional index was needed. | 0.600 | 1.2% | Yes |
| W02 | 2.406 | The pending-invitation index finds the oldest invitation for this recipient. | 0.147 | 93.9% | Yes |
| W03 | 3.397 | The same pending-invitation index finds the invitation used to create the connection. | 0.358 | 89.5% | Yes |
| W04 | 2.236 | The partial index contains open jobs and helps find the ones past their closing date. | 2.681 | -19.9% | Yes |
| W05 | 2.878 | The partial index narrows applications that are still APPLIED by job and date. | 1.878 | 34.7% | Yes |
| **Total** | **544.037** | | **105.794** | **80.6%** | |

The Phase 3 total is the average of each full run. Adding the rounded query averages gives 544.034 ms, a 0.003 ms rounding difference.

## Checking the results

For each rewritten read query, we compared the original and new results in both directions with `EXCEPT ALL`. A difference count of zero means the rows and duplicate counts matched.

| Query | Original rows | New rows | Difference rows | Check |
|---|---:|---:|---:|---|
| R03 | 14 | 14 | 0 | Same rows |
| R04 | 1 | 1 | 0 | Same rows |
| R05 | 20 | 20 | 0 | Same rows |
| R15 | 20 | 20 | 0 | Same rows |
| R19 | 200 | 200 | 0 | Same rows |
| R20 | 30 | 30 | 0 | Same rows |
| R21 | 72 | 72 | 0 | Same rows |

R13 is the exception. Some profile views have a NULL `viewer_id` because the viewer used private mode. The original `NOT IN` query returned zero rows when it encountered those NULLs. We changed it to `NOT EXISTS`; it returns 6,513 members who have not viewed a profile. That is the result the query is meant to find, but it cannot match the original query’s incorrect empty result.

W02 now uses `ORDER BY invitation_id LIMIT 1` instead of `min(invitation_id)`. Both select the oldest pending invitation. The other queries were left as supplied.

## Plans to compare

These five pairs show some of the clearest plan changes. Each linked file has every run and the full `EXPLAIN` output.

| Query | Before | After |
|---|---|---|
| R23 | A sequential scan of 40,000 members for `lower(email)`; average 8.697 ms. [Plan](../benchmarks/results/baseline/R23.txt) | An index scan using `members_lower_email_idx`; average 0.021 ms. [Plan](../benchmarks/results/optimized/R23.txt) |
| R04 | Two parallel scans of the connections table; average 9.044 ms. [Plan](../benchmarks/results/baseline/R04.txt) | Indexed lookups for both endpoints; average 0.073 ms. [Plan](../benchmarks/results/optimized/R04.txt) |
| R02 | A full scan of positions; average 3.266 ms. [Plan](../benchmarks/results/baseline/R02.txt) | An index-only scan using `positions_member_start_idx`; average 0.053 ms. [Plan](../benchmarks/results/optimized/R02.txt) |
| R03 | A bitmap scan with a bitmap OR for the two endpoints; average 2.426 ms. [Plan](../benchmarks/results/baseline/R03.txt) | Two index lookups followed by a small sort; average 0.041 ms. [Plan](../benchmarks/results/optimized/R03.txt) |
| R01 | A full scan of positions to find the current role; average 5.273 ms. [Plan](../benchmarks/results/baseline/R01.txt) | Index lookups for the member, position and company; average 0.072 ms. [Plan](../benchmarks/results/optimized/R01.txt) |

Here are the main scan steps from the first run of each plan:

```text
R23 before: Seq Scan on members
R23 after:  Index Scan using members_lower_email_idx

R04 before: Parallel Seq Scan on connections (twice)
R04 after:  Append of indexed endpoint lookups -> Hash Join

R02 before: Seq Scan on positions
R02 after:  Index Only Scan using positions_member_start_idx

R03 before: Bitmap Heap Scan -> BitmapOr
R03 after:  Append of indexed endpoint lookups -> Sort

R01 before: Seq Scan on positions
R01 after:  Index Only Scan using positions_member_start_idx
```

## Indexes and write time

Each index in `sql/05_indexes.sql` has a comment explaining which queries use it and why its columns are in that order. The main indexes cover member histories, both connection endpoints, skills, pending invitations, profile views, job dates, and application dates and statuses. For sign-in, we indexed the same `lower(email)` expression used in the query.

The new indexes take about 55 MB; the database was 155 MB after indexing. Indexes take extra space and need updating when rows change. W02 and W03 got faster because they can find pending invitations directly. W04 averaged 2.681 ms, compared with 2.236 ms in the baseline; closing jobs still requires updating each matching row and its index entries. W05 averaged 1.878 ms, compared with 2.878 ms. The PostgreSQL version difference also applies to these comparisons.

R17 and R25 still read the position history for their window functions, so they remain among the slower queries. R15 and R24 summarize many rows, which limits how much an index can help.
