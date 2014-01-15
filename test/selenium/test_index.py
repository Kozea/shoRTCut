
def test_index(s):
    s.go('/')
    assert 'WebRTC' in s.title
    assert s('video')
