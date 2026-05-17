package main

import (
	"encoding/json"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/bff/hello", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "hello from go bff"})
	})

	http.HandleFunc("/bff/users", func(w http.ResponseWriter, r *http.Request) {
		users := []map[string]string{{"id": "1", "name": "Alice"}, {"id": "2", "name": "Bob"}}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(users)
	})

	log.Println("starting go bff on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}
