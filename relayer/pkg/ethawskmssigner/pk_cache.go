package ethawskmssigner

import (
	"crypto/ecdsa"
	"sync"
)

type pubKeyCache struct {
	pubKeys map[string]*ecdsa.PublicKey
	mutex   sync.RWMutex
}

func newPubKeyCache() *pubKeyCache {
	return &pubKeyCache{
		pubKeys: make(map[string]*ecdsa.PublicKey),
	}
}

func (c *pubKeyCache) add(keyId string, key *ecdsa.PublicKey) {
	c.mutex.Lock()
	c.pubKeys[keyId] = key
	c.mutex.Unlock()
}

func (c *pubKeyCache) get(keyId string) *ecdsa.PublicKey {
	c.mutex.RLock()
	defer c.mutex.RUnlock()
	return c.pubKeys[keyId]
}
