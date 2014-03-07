
def test_index(s):
    s.go('/')
    assert 'shoRTCut' in s.title
    assert s('video')
