"""The reciter's own verdict on a flagged word.

The detector wrongly flags roughly two correct recitations in five, so pressing
"I said it right" is an ordinary event, not an edge case -- and what it stores is
the only per-word judgement on real learner recitation that exists anywhere.
Both of the rules that keep that record usable are pinned here: one entry per
word, and a session that isn't yours is not found.
"""
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import firestore_service  # noqa: E402


class FakeDoc:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None
        self.updates = []

    def to_dict(self):
        return dict(self._data)

    def get(self):
        return self

    def update(self, patch_):
        self.updates.append(patch_)
        self._data.update(patch_)

    # The chain firestore_service walks: collection/document/collection/document
    def collection(self, _name):
        return self

    def document(self, _id=None):
        return self


@pytest.fixture
def session_doc():
    doc = FakeDoc({"surahNumber": 112})
    with patch.object(firestore_service, "get_firestore_client", return_value=doc):
        yield doc


def test_records_a_disagreement(session_doc):
    out = firestore_service.record_word_feedback("uid", "sess", ayah_number=2, word_index=3, agreed=False)

    assert out["word_feedback_count"] == 1
    entry = session_doc.updates[-1]["wordFeedback"][0]
    assert (entry["ayahNumber"], entry["wordIndex"], entry["agreed"]) == (2, 3, False)
    assert entry["at"] is not None


def test_pressing_the_same_word_twice_replaces_rather_than_stacks(session_doc):
    firestore_service.record_word_feedback("uid", "sess", ayah_number=2, word_index=3, agreed=False)
    out = firestore_service.record_word_feedback("uid", "sess", ayah_number=2, word_index=3, agreed=True)

    # One word, one verdict -- otherwise a training set built from this would
    # contain both answers for the same word and no way to tell which stood.
    assert out["word_feedback_count"] == 1
    assert session_doc.updates[-1]["wordFeedback"][0]["agreed"] is True


def test_different_words_accumulate(session_doc):
    firestore_service.record_word_feedback("uid", "sess", ayah_number=2, word_index=3, agreed=False)
    out = firestore_service.record_word_feedback("uid", "sess", ayah_number=2, word_index=4, agreed=False)

    assert out["word_feedback_count"] == 2


def test_unknown_session_is_reported_not_created():
    missing = FakeDoc(None)
    with patch.object(firestore_service, "get_firestore_client", return_value=missing):
        with pytest.raises(KeyError):
            firestore_service.record_word_feedback("uid", "nope", ayah_number=1, word_index=0, agreed=False)
    # A session id that isn't this user's must not become one.
    assert missing.updates == []
