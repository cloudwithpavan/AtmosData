def test_fixed_project_configuration():
    project_id = "my-project-77-511616"
    region = "asia-south1"
    cities = {"Hyderabad", "Bengaluru", "Mumbai", "Delhi", "Chennai"}
    assert project_id == "my-project-77-511616"
    assert region == "asia-south1"
    assert len(cities) == 5
