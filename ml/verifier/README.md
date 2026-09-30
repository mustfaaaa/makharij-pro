# Tajweed flag verifier

This is MakharijPro's trainable layer on top of the Quran phoneme recogniser.
It answers a narrower question than ASR: **is this flagged word supported well
enough to count as a real learner error?**

1. Export session dictionaries from Firestore as JSON.
2. Build anonymised word rows:

   ```powershell
   python ml/verifier/build_feedback_dataset.py sessions.json feedback.jsonl --salt "private-random-salt"
   ```

3. After teacher review produces at least 200 verified words from 20 learners
   (the script's safety floor; 1,000–2,000 words is the real target), train:

   ```powershell
   python ml/verifier/train_verifier.py feedback.jsonl verifier.json
   ```

The split is by anonymised learner id, not by word, so the validation set
contains voices the verifier never trained on. By default learner self-reports
are excluded: `I said it right` is useful signal, not ground truth. The
`--include-self-reports` flag exists only for explicitly exploratory runs and
marks the exported artifact accordingly.

No model artifact is enabled in production merely because training completed.
Its held-out false-confirmation rate and real-error recall must beat the current
policy before integration.
