/**
 * Fix user predictions whose matchId no longer exists in `matches` (e.g. after re-seed).
 * Resolves the correct match by matchTag and either updates matchId or drops a duplicate.
 *
 * Usage:
 *   API_ENV_FILE=.env.fcc npx tsx scripts/fixOrphanedPredictionMatchIds.ts --dry-run
 *   API_ENV_FILE=.env.fcc npx tsx scripts/fixOrphanedPredictionMatchIds.ts
 */
import '../src/config/loadEnv';
import {
  connectMongo,
  disconnectMongo,
  getMatchesCollection,
  getUsersCollection,
  toObjectId,
} from '../src/lib/mongodb';
import type { EmbeddedPrediction } from '../src/db/types';
import { sumPredictionPoints } from '../src/db/helpers';

const dryRun = process.argv.includes('--dry-run');

async function matchExists(matchId: string): Promise<boolean> {
  const oid = toObjectId(matchId);
  if (!oid) return false;
  return (await getMatchesCollection().countDocuments({ _id: oid })) > 0;
}

async function findMatchIdByTag(matchTag: string): Promise<string | null> {
  const match = await getMatchesCollection().findOne({ matchTag });
  return match?._id.toString() ?? null;
}

async function main() {
  await connectMongo();
  const usersCol = getUsersCollection();

  const users = await usersCol.find({}).toArray();
  let usersFixed = 0;
  let updated = 0;
  let removed = 0;

  for (const user of users) {
    const fixes: string[] = [];
    const kept: EmbeddedPrediction[] = [];

    for (const prediction of user.predictions) {
      const exists = await matchExists(prediction.matchId);
      if (exists) {
        kept.push(prediction);
        continue;
      }

      if (!prediction.matchTag) {
        fixes.push(`remove ${prediction.matchId} (orphaned, no matchTag)`);
        removed++;
        continue;
      }

      const correctMatchId = await findMatchIdByTag(prediction.matchTag);
      if (!correctMatchId) {
        fixes.push(`remove ${prediction.matchId} (${prediction.matchTag}, no match in DB)`);
        removed++;
        continue;
      }

      const superseded = user.predictions.some((p) => p.matchId === correctMatchId);
      const alreadyKept = kept.some((p) => p.matchId === correctMatchId);
      if (superseded || alreadyKept) {
        fixes.push(
          `remove stale ${prediction.matchId} (${prediction.matchTag}) — keeping ${correctMatchId}`
        );
        removed++;
        continue;
      }

      fixes.push(`update ${prediction.matchId} → ${correctMatchId} (${prediction.matchTag})`);
      kept.push({ ...prediction, matchId: correctMatchId });
      updated++;
    }

    if (fixes.length === 0) continue;

    usersFixed++;
    console.log(`\n${user.email}:`);
    fixes.forEach((line) => console.log(`  ${line}`));

    if (!dryRun) {
      await usersCol.updateOne(
        { _id: user._id },
        {
          $set: {
            predictions: kept,
            totalPoints: sumPredictionPoints(kept),
            updatedAt: new Date(),
          },
        }
      );
    }
  }

  console.log(
    `\n${dryRun ? '[dry-run] ' : ''}Done: ${usersFixed} user(s), ${updated} matchId update(s), ${removed} stale removal(s).`
  );

  await disconnectMongo();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
